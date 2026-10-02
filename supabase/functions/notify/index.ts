// Sends booking confirmation and cancellation e-mails through Gmail SMTP.
// Called only by the appointments_notify database trigger (shared secret header).
// GMAIL_USER is the sender customers see; SALON_EMAIL (private) receives owner copies.
import nodemailer from "npm:nodemailer@6.9.16";

const env = (name: string) => Deno.env.get(name) ?? "";
const transport = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 465, // Supabase Edge Functions block outbound 25/587.
  secure: true,
  auth: { user: env("GMAIL_USER").trim(), pass: env("GMAIL_APP_PASSWORD").replace(/\s/g, "") },
});

type Event = {
  type: "booked" | "cancelled";
  client_name: string;
  client_email: string;
  client_phone: string;
  service: string;
  starts_at: string;
  duration_minutes: number;
  price: number;
  cancel_token: string;
  cancelled_by: string | null;
};

const when = (iso: string) =>
  new Intl.DateTimeFormat("tr-TR", {
    timeZone: "Europe/Amsterdam",
    weekday: "long", day: "2-digit", month: "long", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  }).format(new Date(iso));

function messages(e: Event) {
  const site = env("SITE_URL").replace(/\/?$/, "/");
  const details = `Hizmet: ${e.service}\nTarih: ${when(e.starts_at)} (Amsterdam saati)\nSüre: ${e.duration_minutes} dakika\nÜcret: €${e.price}`;
  if (e.type === "booked") {
    return {
      customer: {
        subject: "Randevunuz onaylandı – Beauty Studio",
        text: `Merhaba ${e.client_name},\n\nRandevunuz alındı.\n\n${details}\n\n` +
          `İptal etmeniz gerekirse randevudan en geç 24 saat önce bu bağlantıyı kullanın:\n${site}#/iptal?t=${e.cancel_token}\n\n` +
          `Görüşmek üzere,\nBeauty Studio`,
      },
      salon: {
        subject: `Yeni randevu: ${e.client_name} – ${when(e.starts_at)}`,
        text: `${details}\n\nMüşteri: ${e.client_name}\nE-posta: ${e.client_email}\nTelefon: ${e.client_phone}`,
      },
    };
  }
  const byCustomer = e.cancelled_by === "customer";
  return {
    customer: {
      subject: "Randevunuz iptal edildi – Beauty Studio",
      text: `Merhaba ${e.client_name},\n\n` +
        (byCustomer ? "İptal talebiniz alındı. " : "Randevunuz salon tarafından iptal edildi. ") +
        `Aşağıdaki randevu artık geçerli değil.\n\n${details}\n\nYeni randevu için: ${site}\n\nBeauty Studio`,
    },
    salon: {
      subject: `Randevu iptal edildi (${byCustomer ? "müşteri" : "admin"}): ${e.client_name} – ${when(e.starts_at)}`,
      text: `${details}\n\nMüşteri: ${e.client_name}\nE-posta: ${e.client_email}\nTelefon: ${e.client_phone}`,
    },
  };
}

Deno.serve(async (req) => {
  const secret = env("NOTIFY_WEBHOOK_SECRET");
  if (req.method !== "POST" || !secret || req.headers.get("x-webhook-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }
  const event = (await req.json()) as Event;
  if (event.type !== "booked" && event.type !== "cancelled") {
    return new Response("bad request", { status: 400 });
  }
  const from = `Beauty Studio <${env("GMAIL_USER")}>`;
  const salonInbox = env("SALON_EMAIL") || env("GMAIL_USER");
  const { customer, salon } = messages(event);
  try {
    await transport.sendMail({ from, to: event.client_email, replyTo: env("GMAIL_USER"), ...customer });
    await transport.sendMail({ from, to: salonInbox, ...salon });
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    console.error("mail failed", reason);
    // Only the database trigger can read this response (secret-protected endpoint).
    return new Response(`mail failed: ${reason.slice(0, 200)}`, { status: 502 });
  }
  return new Response("ok");
});

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
  new Intl.DateTimeFormat("nl-NL", {
    timeZone: "Europe/Amsterdam",
    weekday: "long", day: "2-digit", month: "long", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  }).format(new Date(iso));

function messages(e: Event) {
  const site = env("SITE_URL").replace(/\/?$/, "/");
  const details = `Behandeling: ${e.service}\nDatum: ${when(e.starts_at)} (Nederlandse tijd)\nDuur: ${e.duration_minutes} minuten\nPrijs: €${e.price}`;
  if (e.type === "booked") {
    return {
      customer: {
        subject: "Je afspraak is bevestigd – Brow Belle",
        text: `Hallo ${e.client_name},\n\nJe afspraak is gemaakt.\n\n${details}\n\n` +
          `Wil je annuleren? Gebruik dan uiterlijk 24 uur voor je afspraak deze link:\n${site}#/annuleren?t=${e.cancel_token}\n\n` +
          `Tot ziens,\nBrow Belle`,
      },
      salon: {
        subject: `Nieuwe afspraak: ${e.client_name} – ${when(e.starts_at)}`,
        text: `${details}\n\nKlant: ${e.client_name}\nE-mail: ${e.client_email}\nTelefoon: ${e.client_phone}`,
      },
    };
  }
  const byCustomer = e.cancelled_by === "customer";
  return {
    customer: {
      subject: "Je afspraak is geannuleerd – Brow Belle",
      text: `Hallo ${e.client_name},\n\n` +
        (byCustomer ? "Je annulering is ontvangen. " : "Je afspraak is door de salon geannuleerd. ") +
        `De onderstaande afspraak gaat niet door.\n\n${details}\n\nNieuwe afspraak maken: ${site}\n\nBrow Belle`,
    },
    salon: {
      subject: `Afspraak geannuleerd (${byCustomer ? "klant" : "salon"}): ${e.client_name} – ${when(e.starts_at)}`,
      text: `${details}\n\nKlant: ${e.client_name}\nE-mail: ${e.client_email}\nTelefoon: ${e.client_phone}`,
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
  const from = `Brow Belle <${env("GMAIL_USER")}>`;
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

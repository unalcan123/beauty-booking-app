// Sends booking confirmation and cancellation e-mails through the Resend API.
// Called only by the appointments_notify database trigger (shared secret header).
// Mail goes out from MAIL_FROM (a verified Resend domain); SALON_EMAIL (private, optional)
// receives owner copies and REPLY_TO (optional) is where customer replies land.
const env = (name: string) => Deno.env.get(name) ?? "";

type Mail = { from: string; to: string; subject: string; text: string; reply_to?: string };

async function send(mail: Mail) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${env("RESEND_API_KEY").trim()}`, "Content-Type": "application/json" },
    body: JSON.stringify(mail),
  });
  if (!res.ok) throw new Error(`resend ${res.status}: ${await res.text()}`);
}

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
  const from = env("MAIL_FROM") || "Brow Belle <info@browbelle.nl>";
  const replyTo = env("REPLY_TO");
  const salonInbox = env("SALON_EMAIL"); // empty: no owner copy
  const { customer, salon } = messages(event);
  try {
    await send({ from, to: event.client_email, ...(replyTo && { reply_to: replyTo }), ...customer });
    if (salonInbox) await send({ from, to: salonInbox, ...salon });
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    console.error("mail failed", reason);
    // Only the database trigger can read this response (secret-protected endpoint).
    return new Response(`mail failed: ${reason.slice(0, 200)}`, { status: 502 });
  }
  return new Response("ok");
});

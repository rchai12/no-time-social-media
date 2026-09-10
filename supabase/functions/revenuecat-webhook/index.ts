import { supabaseAdmin } from "../_shared/supabaseClient.ts";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const signature = req.headers.get("X-RevenueCat-Signature") ?? "";
  const rawBody = await req.text();
  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBytes = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(rawBody),
  );
  const expected = Array.from(new Uint8Array(sigBytes))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  if (signature !== expected) {
    return new Response("Unauthorized", { status: 401 });
  }

  const payload = JSON.parse(rawBody);
  const event = payload?.event;
  if (!event) return new Response("{}", { status: 200 });

  const userId = event.app_user_id as string;
  const eventType = event.type as string;
  const expiresAtMs = event.expiration_at_ms as number | undefined;
  const expiresAt = expiresAtMs ? new Date(expiresAtMs).toISOString() : null;

  switch (eventType) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
      await supabaseAdmin.from("subscriptions").upsert({
        user_id: userId,
        tier: "pro",
        expires_at: expiresAt,
        updated_at: new Date().toISOString(),
      });
      break;

    case "EXPIRATION":
      await supabaseAdmin.from("subscriptions").upsert({
        user_id: userId,
        tier: "free",
        expires_at: null,
        updated_at: new Date().toISOString(),
      });
      break;

    case "CANCELLATION":
    case "BILLING_ISSUE":
      console.log(
        `RevenueCat event ${eventType} for user ${userId} — no action`,
      );
      break;

    default:
      console.log(`Unhandled RevenueCat event: ${eventType}`);
  }

  return new Response("{}", {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});

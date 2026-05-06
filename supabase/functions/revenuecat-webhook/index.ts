// supabase/functions/revenuecat-webhook
//
// Mirrors RevenueCat events into the `entitlements` table and flips
// profiles.is_premium (cached convenience flag — RC remains source of truth
// in-app via EntitlementService).
//
// Required env:
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//   REVENUECAT_WEBHOOK_AUTH    (shared secret; set RC's "Authorization header" to
//                              `Bearer <REVENUECAT_WEBHOOK_AUTH>` when registering.)
//
// RC payload reference: https://www.revenuecat.com/docs/webhooks#sample-events

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface RCEvent {
  type: string;                // INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, ...
  app_user_id: string;         // we set this to the Supabase user UUID
  product_id?: string;
  expiration_at_ms?: number;
  store?: string;              // APP_STORE | PLAY_STORE | STRIPE | PROMOTIONAL
  entitlement_ids?: string[];
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });

  const expected = Deno.env.get("REVENUECAT_WEBHOOK_AUTH");
  const got = req.headers.get("Authorization") ?? "";
  if (!expected || got !== `Bearer ${expected}`) {
    return new Response("unauthorized", { status: 401 });
  }

  let event: { event: RCEvent };
  try { event = await req.json(); }
  catch { return new Response("bad json", { status: 400 }); }

  const e = event?.event;
  if (!e?.app_user_id) return new Response("missing app_user_id", { status: 400 });

  const userId = e.app_user_id;
  const productId = e.product_id ?? "unknown";
  const renewsAt = e.expiration_at_ms ? new Date(e.expiration_at_ms).toISOString() : null;
  const store = mapStore(e.store);

  const isActive = activeFromType(e.type);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Upsert entitlement row.
  const { error: entErr } = await supabase
    .from("entitlements")
    .upsert({
      user_id: userId,
      product_id: productId,
      is_active: isActive,
      renews_at: renewsAt,
      store,
      raw: event,
    }, { onConflict: "user_id,product_id" });
  if (entErr) return new Response(entErr.message, { status: 500 });

  // Reflect on profiles.is_premium for cheap server-side reads.
  const { error: profErr } = await supabase
    .from("profiles")
    .update({ is_premium: isActive })
    .eq("id", userId);
  if (profErr) return new Response(profErr.message, { status: 500 });

  return new Response("ok", { status: 200 });
});

function activeFromType(type: string): boolean {
  switch (type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
    case "UNCANCELLATION":
    case "TRANSFER":
      return true;
    case "CANCELLATION":
    case "EXPIRATION":
    case "BILLING_ISSUE":
    case "SUBSCRIPTION_PAUSED":
      return false;
    default:
      return false;
  }
}

function mapStore(rc?: string): string {
  switch (rc) {
    case "APP_STORE": return "app_store";
    case "PLAY_STORE": return "play_store";
    case "STRIPE": return "stripe";
    case "PROMOTIONAL": return "promo";
    default: return "app_store";
  }
}

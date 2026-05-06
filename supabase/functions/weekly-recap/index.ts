// supabase/functions/weekly-recap
//
// Cron-triggered (Sundays 18:00 user-local) — generates per-user weekly
// summary rows used to power notifications and an in-app banner. Stores
// results into app_config under per-user keys so the iOS client can read
// them without an extra table.
//
// Schedule via Supabase pg_cron:
//   select cron.schedule('weekly-recap', '0 18 * * 0',
//     $$ select net.http_post('https://<project>.functions.supabase.co/weekly-recap',
//          '{}'::jsonb,
//          headers => '{"Authorization":"Bearer <SERVICE_ROLE>"}'::jsonb) $$);

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (_req: Request) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Pull session aggregates for the last 7 days, one row per user.
  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const { data, error } = await supabase
    .from("sessions")
    .select("user_id, duration_minutes")
    .gte("started_at", since)
    .not("ended_at", "is", null);
  if (error) return new Response(error.message, { status: 500 });

  const grouped = new Map<string, { count: number; total: number }>();
  for (const row of data ?? []) {
    const id = row.user_id as string;
    const dur = (row.duration_minutes as number | null) ?? 0;
    const cur = grouped.get(id) ?? { count: 0, total: 0 };
    cur.count += 1;
    cur.total += dur;
    grouped.set(id, cur);
  }

  for (const [userId, agg] of grouped) {
    const avg = agg.count > 0 ? Math.round(agg.total / agg.count) : 0;
    const payload = {
      session_count: agg.count,
      average_minutes: avg,
      generated_at: new Date().toISOString(),
    };
    await supabase.from("app_config").upsert({
      key: `recap.${userId}`,
      value: payload,
    });
  }

  return new Response(JSON.stringify({ users: grouped.size }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

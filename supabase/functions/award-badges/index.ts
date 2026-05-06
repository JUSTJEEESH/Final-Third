// supabase/functions/award-badges
//
// Periodic sweep that awards reputation badges based on session and
// chemistry data. Run via pg_cron daily.
//
// Rules (v1):
//   first_light  - completed at least one session
//   ember        - 3-day streak
//   flame        - 7-day streak
//   fire         - 30-day streak
//   regular      - 4 sessions in the last 7 days
//   palate_pro   - 10+ sessions with all three ratings filled
//   good_company - shared >= 3 sessions with the same connection

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (_req: Request) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Resolve badge IDs once.
  const { data: badgeRows, error: badgeErr } = await supabase
    .from("badges")
    .select("id, code");
  if (badgeErr) return new Response(badgeErr.message, { status: 500 });
  const badgeId = (code: string) =>
    badgeRows?.find((b) => b.code === code)?.id as string | undefined;

  const since7d = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

  // 1) first_light + palate_pro
  const { data: sessionUsers } = await supabase
    .from("sessions")
    .select("user_id, flavor_rating, draw_rating, overall_rating")
    .not("ended_at", "is", null);

  const userStats = new Map<string, { sessions: number; rated: number }>();
  for (const r of sessionUsers ?? []) {
    const cur = userStats.get(r.user_id) ?? { sessions: 0, rated: 0 };
    cur.sessions += 1;
    if (r.flavor_rating != null && r.draw_rating != null && r.overall_rating != null) {
      cur.rated += 1;
    }
    userStats.set(r.user_id, cur);
  }
  for (const [userId, stats] of userStats) {
    if (stats.sessions >= 1) await award(supabase, userId, badgeId("first_light"));
    if (stats.rated >= 10) await award(supabase, userId, badgeId("palate_pro"));
  }

  // 2) regular: 4 sessions in last 7 days
  const { data: weekly } = await supabase
    .from("sessions")
    .select("user_id")
    .gte("started_at", since7d);
  const weeklyCount = new Map<string, number>();
  for (const r of weekly ?? []) {
    weeklyCount.set(r.user_id, (weeklyCount.get(r.user_id) ?? 0) + 1);
  }
  for (const [userId, count] of weeklyCount) {
    if (count >= 4) await award(supabase, userId, badgeId("regular"));
  }

  // 3) streak badges via usuals.streak_count
  const { data: usuals } = await supabase
    .from("usuals")
    .select("user_id, streak_count");
  for (const u of usuals ?? []) {
    const c = u.streak_count as number;
    if (c >= 3) await award(supabase, u.user_id as string, badgeId("ember"));
    if (c >= 7) await award(supabase, u.user_id as string, badgeId("flame"));
    if (c >= 30) await award(supabase, u.user_id as string, badgeId("fire"));
  }

  // 4) good_company: pairs with >= 3 sessions together
  const { data: pairs } = await supabase
    .from("connection_chemistry")
    .select("user_a, user_b, sessions_together")
    .gte("sessions_together", 3);
  const goodCompany = badgeId("good_company");
  for (const p of pairs ?? []) {
    if (!goodCompany) break;
    await award(supabase, p.user_a as string, goodCompany);
    await award(supabase, p.user_b as string, goodCompany);
  }

  return new Response("ok", { status: 200 });
});

async function award(
  supabase: any,
  userId: string,
  badgeId: string | undefined,
): Promise<void> {
  if (!badgeId) return;
  await supabase
    .from("user_badges")
    .upsert({ user_id: userId, badge_id: badgeId }, { onConflict: "user_id,badge_id" });
}

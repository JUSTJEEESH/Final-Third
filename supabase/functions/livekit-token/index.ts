// supabase/functions/livekit-token
//
// Issues a LiveKit access token for the requesting user, scoped to a single
// voice room. Validates that the user is a member of the underlying chat
// room and that the speaker slot count for the voice room is not exceeded.
//
// Required env (set in Supabase project secrets):
//   LIVEKIT_API_KEY
//   LIVEKIT_API_SECRET
//   LIVEKIT_URL          (wss://...)
//
// Invoked from iOS via supabase.functions.invoke("livekit-token", body: { room_id: <uuid> }).

// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { AccessToken } from "https://esm.sh/livekit-server-sdk@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "missing auth" }, 401);

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON, {
      global: { headers: { Authorization: authHeader } },
    });

    // Identify caller via the access token attached to the function invocation.
    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData?.user) return json({ error: "unauthorized" }, 401);
    const userId = userData.user.id;

    const body = await req.json().catch(() => ({} as any));
    const roomId = body?.room_id as string | undefined;
    if (!roomId) return json({ error: "room_id required" }, 400);

    // Confirm membership in the underlying room (RLS enforces this implicitly,
    // but checking explicitly returns a clearer error message to the client).
    const { data: membership, error: memberErr } = await supabase
      .from("room_members")
      .select("user_id")
      .eq("room_id", roomId)
      .eq("user_id", userId)
      .maybeSingle();
    if (memberErr) return json({ error: memberErr.message }, 500);
    if (!membership) return json({ error: "not a member of this room" }, 403);

    // Look up the voice room — create one with default 6 speakers if missing.
    const service = createClient(
      SUPABASE_URL,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let { data: voiceRoom } = await service
      .from("voice_rooms")
      .select("id, max_speakers")
      .eq("room_id", roomId)
      .maybeSingle();

    if (!voiceRoom) {
      const { data: created } = await service
        .from("voice_rooms")
        .insert({ room_id: roomId })
        .select("id, max_speakers")
        .single();
      voiceRoom = created;
    }
    if (!voiceRoom) return json({ error: "voice room unavailable" }, 500);

    // Speaker slot count check — listeners pass through unconditionally.
    const { count } = await service
      .from("voice_participants")
      .select("user_id", { count: "exact", head: true })
      .eq("voice_room_id", voiceRoom.id)
      .eq("role", "speaker");
    const canSpeak = (count ?? 0) < voiceRoom.max_speakers;

    // Issue the access token.
    const apiKey = Deno.env.get("LIVEKIT_API_KEY")!;
    const apiSecret = Deno.env.get("LIVEKIT_API_SECRET")!;
    const at = new AccessToken(apiKey, apiSecret, {
      identity: userId,
      ttl: 60 * 60, // 1 hour
    });
    at.addGrant({
      roomJoin: true,
      room: `voice:${roomId}`,
      canPublish: canSpeak,
      canPublishData: true,
      canSubscribe: true,
    });

    const token = await at.toJwt();
    return json({ token, can_speak: canSpeak });
  } catch (err) {
    return json({ error: (err as Error).message }, 500);
  }
});

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

import Foundation
import Supabase

protocol RoomRepository: Sendable {
    func list() async throws -> [Room]
    func fetch(id: UUID) async throws -> Room
    func create(name: String, isPrivate: Bool, theme: String?, audioTheme: AudioTheme?) async throws -> Room
    func join(roomID: UUID) async throws
    func leave(roomID: UUID) async throws
    func setPresence(roomID: UUID, isGhost: Bool) async throws
    /// Per-room "lit up right now" aggregate (count + sample of
    /// smokers with cigars). Powers the doorway sheet's live-now
    /// section. Returns a dictionary keyed by roomID; rooms with no
    /// active sessions are absent.
    func liveNow(roomIDs: [UUID]) async throws -> [UUID: LiveNowSummary]
}

struct LiveRoomRepository: RoomRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func list() async throws -> [Room] {
        let dtos: [DTO.Room] = try await client.from("rooms").select()
            .order("created_at", ascending: false).limit(100).execute().value
        return dtos.map { $0.toDomain() }
    }

    func fetch(id: UUID) async throws -> Room {
        let dto: DTO.Room = try await client.from("rooms").select()
            .eq("id", value: id.uuidString).single().execute().value
        return dto.toDomain()
    }

    func create(name: String, isPrivate: Bool, theme: String?, audioTheme: AudioTheme?) async throws -> Room {
        let userID = try await client.auth.session.user.id
        struct Insert: Encodable {
            let owner_id: UUID
            let name: String
            let is_private: Bool
            let theme: String?
            let audio_theme: String?
        }
        let dto: DTO.Room = try await client.from("rooms")
            .insert(Insert(
                owner_id: userID, name: name, is_private: isPrivate,
                theme: theme, audio_theme: audioTheme?.rawValue
            ))
            .select().single().execute().value
        return dto.toDomain()
    }

    func join(roomID: UUID) async throws {
        let userID = try await client.auth.session.user.id
        struct Member: Encodable { let room_id: UUID; let user_id: UUID }
        try await client.from("room_members")
            .upsert(Member(room_id: roomID, user_id: userID), onConflict: "room_id,user_id")
            .execute()
    }

    func leave(roomID: UUID) async throws {
        let userID = try await client.auth.session.user.id
        try await client.from("room_members")
            .delete()
            .eq("room_id", value: roomID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
        try await client.from("room_presence")
            .delete()
            .eq("room_id", value: roomID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
    }

    func setPresence(roomID: UUID, isGhost: Bool) async throws {
        let userID = try await client.auth.session.user.id
        struct Presence: Encodable {
            let room_id: UUID
            let user_id: UUID
            let is_ghost: Bool
        }
        try await client.from("room_presence")
            .upsert(Presence(room_id: roomID, user_id: userID, is_ghost: isGhost),
                    onConflict: "room_id,user_id")
            .execute()
    }

    func liveNow(roomIDs: [UUID]) async throws -> [UUID: LiveNowSummary] {
        guard !roomIDs.isEmpty else { return [:] }
        struct Args: Encodable { let p_room_ids: [UUID] }
        // The RPC returns one row per room with active (non-ghost)
        // sessions. We decode each row into a small intermediate
        // shape, then domainize. `smokers` is jsonb on the wire — the
        // Supabase Swift SDK decodes it directly into our nested
        // Codable type because the JSON shape matches.
        struct Row: Decodable {
            let room_id: UUID
            let live_count: Int
            let smokers: [SmokerRow]
        }
        struct SmokerRow: Decodable {
            let user_id: UUID
            let display_name: String
            let avatar_url: String?
            let cigar_brand: String?
            let cigar_line: String?
            let minutes_in: Int
        }
        let rows: [Row] = try await client
            .rpc("room_live_now", params: Args(p_room_ids: roomIDs))
            .execute()
            .value

        var out: [UUID: LiveNowSummary] = [:]
        for row in rows {
            let smokers = row.smokers.map {
                LiveNowSummary.Smoker(
                    userID: $0.user_id,
                    displayName: $0.display_name,
                    avatarURL: $0.avatar_url.flatMap(URL.init(string:)),
                    cigarBrand: $0.cigar_brand,
                    cigarLine: $0.cigar_line,
                    minutesIn: $0.minutes_in
                )
            }
            out[row.room_id] = LiveNowSummary(
                roomID: row.room_id,
                liveCount: row.live_count,
                smokers: smokers
            )
        }
        return out
    }
}

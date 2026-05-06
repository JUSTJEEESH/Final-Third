import Foundation
import Supabase

protocol RoomRepository: Sendable {
    func list() async throws -> [Room]
    func fetch(id: UUID) async throws -> Room
    func create(name: String, isPrivate: Bool, theme: String?, audioTheme: AudioTheme?) async throws -> Room
    func join(roomID: UUID) async throws
    func leave(roomID: UUID) async throws
    func setPresence(roomID: UUID, isGhost: Bool) async throws
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
}

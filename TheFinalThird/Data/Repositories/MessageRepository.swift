import Foundation
import Supabase

protocol MessageRepository: Sendable {
    func page(roomID: UUID, before: Date?, limit: Int) async throws -> [Message]
    func send(roomID: UUID, body: String, clientID: UUID) async throws -> Message
    func edit(messageID: UUID, body: String) async throws
    func delete(messageID: UUID) async throws
    func toggleReaction(messageID: UUID, reaction: MessageReaction.Reaction, on: Bool) async throws
}

struct LiveMessageRepository: MessageRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func page(roomID: UUID, before: Date? = nil, limit: Int = 50) async throws -> [Message] {
        var builder = client.from("messages").select()
            .eq("room_id", value: roomID.uuidString)
            .is("deleted_at", value: nil)
        if let before {
            builder = builder.lt("created_at", value: ISO8601DateFormatter().string(from: before))
        }
        let dtos: [DTO.Message] = try await builder
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return dtos.map { $0.toDomain() }.reversed()
    }

    func send(roomID: UUID, body: String, clientID: UUID) async throws -> Message {
        let userID = try await client.auth.session.user.id
        let payload = DTO.MessageInsert(id: clientID, room_id: roomID, sender_id: userID, body: body)
        let dto: DTO.Message = try await client.from("messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return dto.toDomain()
    }

    func edit(messageID: UUID, body: String) async throws {
        struct Patch: Encodable { let body: String; let edited_at: Date }
        try await client.from("messages")
            .update(Patch(body: body, edited_at: .now))
            .eq("id", value: messageID.uuidString)
            .execute()
    }

    func delete(messageID: UUID) async throws {
        struct Patch: Encodable { let deleted_at: Date }
        try await client.from("messages")
            .update(Patch(deleted_at: .now))
            .eq("id", value: messageID.uuidString)
            .execute()
    }

    func toggleReaction(messageID: UUID, reaction: MessageReaction.Reaction, on: Bool) async throws {
        let userID = try await client.auth.session.user.id
        if on {
            struct Insert: Encodable { let message_id: UUID; let user_id: UUID; let reaction: String }
            try await client.from("message_reactions")
                .insert(Insert(message_id: messageID, user_id: userID, reaction: reaction.rawValue))
                .execute()
        } else {
            try await client.from("message_reactions")
                .delete()
                .eq("message_id", value: messageID.uuidString)
                .eq("user_id", value: userID.uuidString)
                .eq("reaction", value: reaction.rawValue)
                .execute()
        }
    }
}

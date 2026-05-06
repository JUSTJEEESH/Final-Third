import Foundation
import Supabase

protocol SocialRepository: Sendable {
    func connections(userID: UUID) async throws -> [Connection]
    func request(addresseeID: UUID) async throws
    func respond(connectionID: UUID, accept: Bool) async throws
    func chemistry(userID: UUID) async throws -> [ConnectionChemistry]
}

struct LiveSocialRepository: SocialRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func connections(userID: UUID) async throws -> [Connection] {
        let dtos: [DTO.Connection] = try await client.from("connections").select()
            .or("requester_id.eq.\(userID.uuidString),addressee_id.eq.\(userID.uuidString)")
            .order("created_at", ascending: false)
            .execute().value
        return dtos.map { $0.toDomain() }
    }

    func request(addresseeID: UUID) async throws {
        let userID = try await client.auth.session.user.id
        struct Insert: Encodable {
            let requester_id: UUID
            let addressee_id: UUID
            let status: String
        }
        try await client.from("connections")
            .insert(Insert(requester_id: userID, addressee_id: addresseeID, status: "pending"))
            .execute()
    }

    func respond(connectionID: UUID, accept: Bool) async throws {
        struct Patch: Encodable { let status: String }
        try await client.from("connections")
            .update(Patch(status: accept ? "accepted" : "declined"))
            .eq("id", value: connectionID.uuidString)
            .execute()
    }

    func chemistry(userID: UUID) async throws -> [ConnectionChemistry] {
        struct Row: Decodable {
            let user_a: UUID
            let user_b: UUID
            let sessions_together: Int
            let minutes_together: Int?
            let last_session_at: Date?
        }
        let rows: [Row] = try await client.from("connection_chemistry").select()
            .or("user_a.eq.\(userID.uuidString),user_b.eq.\(userID.uuidString)")
            .order("sessions_together", ascending: false)
            .limit(50)
            .execute().value
        return rows.map {
            ConnectionChemistry(
                userA: $0.user_a, userB: $0.user_b,
                sessionsTogether: $0.sessions_together,
                minutesTogether: $0.minutes_together ?? 0,
                lastSessionAt: $0.last_session_at
            )
        }
    }
}

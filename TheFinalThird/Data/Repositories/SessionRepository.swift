import Foundation
import Supabase

protocol SessionRepository: Sendable {
    func recent(userID: UUID, limit: Int) async throws -> [Session]
    func start(userID: UUID, roomID: UUID?, cigarID: UUID?, drinkID: UUID?,
               lightingMethod: Session.LightingMethod?, isGhost: Bool) async throws -> Session
    func finish(_ session: Session) async throws -> Session
    func saveSummary(sessionID: UUID, flavor: Int, draw: Int, overall: Int,
                     wouldSmokeAgain: Bool, mood: Int, unwind: Bool, notes: String?) async throws
}

struct LiveSessionRepository: SessionRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func recent(userID: UUID, limit: Int = 30) async throws -> [Session] {
        let dtos: [DTO.Session] = try await client.from("sessions").select()
            .eq("user_id", value: userID.uuidString)
            .order("started_at", ascending: false)
            .limit(limit)
            .execute().value
        return dtos.map { $0.toDomain() }
    }

    func start(userID: UUID, roomID: UUID?, cigarID: UUID?, drinkID: UUID?,
               lightingMethod: Session.LightingMethod?, isGhost: Bool) async throws -> Session {
        struct Insert: Encodable {
            let id: UUID
            let user_id: UUID
            let room_id: UUID?
            let cigar_id: UUID?
            let drink_id: UUID?
            let started_at: Date
            let lighting_method: String?
            let is_ghost: Bool
        }
        let row = Insert(
            id: UUID(),
            user_id: userID, room_id: roomID, cigar_id: cigarID, drink_id: drinkID,
            started_at: .now,
            lighting_method: lightingMethod?.rawValue, is_ghost: isGhost
        )
        let dto: DTO.Session = try await client.from("sessions")
            .insert(row).select().single().execute().value
        return dto.toDomain()
    }

    func finish(_ session: Session) async throws -> Session {
        struct Patch: Encodable {
            let ended_at: Date
            let duration_minutes: Int
        }
        let endedAt = Date.now
        let mins = Int(endedAt.timeIntervalSince(session.startedAt) / 60)
        let dto: DTO.Session = try await client.from("sessions")
            .update(Patch(ended_at: endedAt, duration_minutes: mins))
            .eq("id", value: session.id.uuidString)
            .select().single().execute().value
        return dto.toDomain()
    }

    func saveSummary(
        sessionID: UUID, flavor: Int, draw: Int, overall: Int,
        wouldSmokeAgain: Bool, mood: Int, unwind: Bool, notes: String?
    ) async throws {
        struct Patch: Encodable {
            let flavor_rating: Int
            let draw_rating: Int
            let overall_rating: Int
            let would_smoke_again: Bool
            let mood_score: Int
            let unwind_success: Bool
            let notes: String?
        }
        try await client.from("sessions")
            .update(Patch(
                flavor_rating: flavor, draw_rating: draw, overall_rating: overall,
                would_smoke_again: wouldSmokeAgain, mood_score: mood,
                unwind_success: unwind, notes: notes
            ))
            .eq("id", value: sessionID.uuidString)
            .execute()
    }
}

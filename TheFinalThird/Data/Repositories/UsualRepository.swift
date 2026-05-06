import Foundation
import Supabase

protocol UsualRepository: Sendable {
    func fetch(userID: UUID) async throws -> Usual?
    func upsert(userID: UUID, time: TimeOfDay?, cigarID: UUID?, drinkID: UUID?, enabled: Bool) async throws
}

struct LiveUsualRepository: UsualRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func fetch(userID: UUID) async throws -> Usual? {
        let dtos: [DTO.Usual] = try await client.from("usuals")
            .select()
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute().value
        return dtos.first.map { $0.toDomain() }
    }

    func upsert(
        userID: UUID,
        time: TimeOfDay?,
        cigarID: UUID?,
        drinkID: UUID?,
        enabled: Bool
    ) async throws {
        struct Upsert: Encodable {
            let user_id: UUID
            let preferred_time: String?
            let cigar_id: UUID?
            let drink_id: UUID?
            let enabled: Bool
        }
        let timeString = time.map { String(format: "%02d:%02d", $0.hour, $0.minute) }
        try await client.from("usuals")
            .upsert(Upsert(
                user_id: userID, preferred_time: timeString,
                cigar_id: cigarID, drink_id: drinkID, enabled: enabled
            ), onConflict: "user_id")
            .execute()
    }
}

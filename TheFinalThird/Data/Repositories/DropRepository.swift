import Foundation
import Supabase

protocol DropRepository: Sendable {
    func current() async throws -> CigarDrop?
    func upcoming(limit: Int) async throws -> [CigarDrop]
}

struct LiveDropRepository: DropRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func current() async throws -> CigarDrop? {
        let nowISO = ISO8601DateFormatter().string(from: .now)
        let dtos: [DTO.Drop] = try await client.from("drops").select()
            .lte("starts_at", value: nowISO)
            .gte("ends_at", value: nowISO)
            .limit(1)
            .execute().value
        return dtos.first.map { $0.toDomain() }
    }

    func upcoming(limit: Int = 5) async throws -> [CigarDrop] {
        let dtos: [DTO.Drop] = try await client.from("drops").select()
            .gte("starts_at", value: ISO8601DateFormatter().string(from: .now))
            .order("starts_at", ascending: true)
            .limit(limit)
            .execute().value
        return dtos.map { $0.toDomain() }
    }
}

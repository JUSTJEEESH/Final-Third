import Foundation
import Supabase

protocol DrinkRepository: Sendable {
    func list(category: String?) async throws -> [Drink]
    func fetch(id: UUID) async throws -> Drink
}

struct LiveDrinkRepository: DrinkRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func list(category: String? = nil) async throws -> [Drink] {
        var builder = client.from("drinks").select()
        if let category { builder = builder.eq("category", value: category) }
        let dtos: [DTO.Drink] = try await builder.order("name").execute().value
        return dtos.map { $0.toDomain() }
    }

    func fetch(id: UUID) async throws -> Drink {
        let dto: DTO.Drink = try await client.from("drinks")
            .select().eq("id", value: id.uuidString).single().execute().value
        return dto.toDomain()
    }
}

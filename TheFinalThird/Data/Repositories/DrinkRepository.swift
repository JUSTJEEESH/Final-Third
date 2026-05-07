import Foundation
import Supabase

struct DrinkFilters: Sendable, Equatable {
    var query: String = ""
    var category: String?
    var subtype: String?
}

protocol DrinkRepository: Sendable {
    func search(_ filters: DrinkFilters, limit: Int) async throws -> [Drink]
    func list(category: String?) async throws -> [Drink]
    func fetch(id: UUID) async throws -> Drink
    func categories() async throws -> [String]
    func submitPending(name: String, category: String?, subtype: String?) async throws
}

struct LiveDrinkRepository: DrinkRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func search(_ filters: DrinkFilters, limit: Int = 200) async throws -> [Drink] {
        var builder = client.from("drinks").select()
        if !filters.query.isEmpty {
            let q = filters.query.replacingOccurrences(of: ",", with: "")
            builder = builder.or("name.ilike.%\(q)%,subtype.ilike.%\(q)%")
        }
        if let category = filters.category {
            builder = builder.eq("category", value: category)
        }
        if let subtype = filters.subtype {
            builder = builder.eq("subtype", value: subtype)
        }
        let dtos: [DTO.Drink] = try await builder
            .order("category", ascending: true)
            .order("name", ascending: true)
            .limit(limit)
            .execute()
            .value
        return dtos.map { $0.toDomain() }
    }

    func list(category: String? = nil) async throws -> [Drink] {
        try await search(DrinkFilters(category: category), limit: 500)
    }

    func fetch(id: UUID) async throws -> Drink {
        let dto: DTO.Drink = try await client.from("drinks")
            .select().eq("id", value: id.uuidString).single().execute().value
        return dto.toDomain()
    }

    /// Returns the distinct list of category values currently in the
    /// drinks catalog, in the order they should appear in pickers
    /// (alphabetical for predictability).
    func categories() async throws -> [String] {
        struct Row: Decodable, Sendable { let category: String }
        let rows: [Row] = try await client.from("drinks")
            .select("category")
            .execute().value
        return Array(Set(rows.map { $0.category })).sorted()
    }

    func submitPending(name: String, category: String?, subtype: String?) async throws {
        let userID = try await client.auth.session.user.id
        struct Pending: Encodable {
            let submitted_by: UUID
            let name: String
            let category: String?
            let subtype: String?
        }
        try await client.from("drinks_pending")
            .insert(Pending(submitted_by: userID, name: name,
                            category: category, subtype: subtype))
            .execute()
    }
}

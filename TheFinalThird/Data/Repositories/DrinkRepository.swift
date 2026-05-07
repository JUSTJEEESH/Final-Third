import Foundation
import Supabase

struct DrinkFilters: Sendable, Equatable {
    var query: String = ""
    var category: String?
    var brand: String?
    var subtype: String?
}

protocol DrinkRepository: Sendable {
    func search(_ filters: DrinkFilters, limit: Int) async throws -> [Drink]
    func list(category: String?) async throws -> [Drink]
    func fetch(id: UUID) async throws -> Drink
    func categories() async throws -> [String]
    func brands(forCategory category: String?) async throws -> [String]
    func submitPending(brand: String?, name: String, category: String?, subtype: String?) async throws
}

struct LiveDrinkRepository: DrinkRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func search(_ filters: DrinkFilters, limit: Int = 200) async throws -> [Drink] {
        var builder = client.from("drinks").select()
        if !filters.query.isEmpty {
            // Hits brand, name, and subtype so a search like "modelo"
            // surfaces "Modelo Negra", "doppelbock" surfaces all
            // doppelbocks regardless of brand, etc.
            let q = filters.query.replacingOccurrences(of: ",", with: "")
            builder = builder.or("brand.ilike.%\(q)%,name.ilike.%\(q)%,subtype.ilike.%\(q)%")
        }
        if let category = filters.category {
            builder = builder.eq("category", value: category)
        }
        if let brand = filters.brand {
            builder = builder.eq("brand", value: brand)
        }
        if let subtype = filters.subtype, !subtype.isEmpty {
            builder = builder.ilike("subtype", pattern: "%\(subtype)%")
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

    /// Distinct brands available, optionally narrowed to a single category.
    /// Used by the filter sheet's brand picker once the user has chosen a
    /// type — hide the noise of every brand across every category.
    func brands(forCategory category: String? = nil) async throws -> [String] {
        struct Row: Decodable, Sendable { let brand: String? }
        var builder = client.from("drinks").select("brand")
        if let category {
            builder = builder.eq("category", value: category)
        }
        let rows: [Row] = try await builder.execute().value
        return Array(Set(rows.compactMap { $0.brand })).sorted()
    }

    func submitPending(
        brand: String?,
        name: String,
        category: String?,
        subtype: String?
    ) async throws {
        let userID = try await client.auth.session.user.id
        struct Pending: Encodable {
            let submitted_by: UUID
            let brand: String?
            let name: String
            let category: String?
            let subtype: String?
        }
        try await client.from("drinks_pending")
            .insert(Pending(submitted_by: userID, brand: brand, name: name,
                            category: category, subtype: subtype))
            .execute()
    }
}

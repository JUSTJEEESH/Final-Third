import Foundation
import Supabase

struct CigarFilters: Sendable, Equatable {
    var query: String = ""
    var country: String?
    var wrapper: String?
    var strength: Int?
}

protocol CigarRepository: Sendable {
    func search(_ filters: CigarFilters, limit: Int) async throws -> [Cigar]
    func fetch(id: UUID) async throws -> Cigar
    func submitPending(brand: String, line: String, vitola: String?, country: String?) async throws
}

struct LiveCigarRepository: CigarRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func search(_ filters: CigarFilters, limit: Int = 50) async throws -> [Cigar] {
        var builder = client.from("cigars").select()
        if !filters.query.isEmpty {
            // case-insensitive substring on brand or line via or() filter
            let q = filters.query.replacingOccurrences(of: ",", with: "")
            builder = builder.or("brand.ilike.%\(q)%,line.ilike.%\(q)%")
        }
        if let country = filters.country {
            builder = builder.eq("country", value: country)
        }
        if let wrapper = filters.wrapper {
            builder = builder.eq("wrapper", value: wrapper)
        }
        if let strength = filters.strength {
            builder = builder.eq("strength", value: strength)
        }
        let dtos: [DTO.Cigar] = try await builder
            .order("brand", ascending: true)
            .limit(limit)
            .execute()
            .value
        return dtos.map { $0.toDomain() }
    }

    func fetch(id: UUID) async throws -> Cigar {
        let dto: DTO.Cigar = try await client
            .from("cigars")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return dto.toDomain()
    }

    func submitPending(brand: String, line: String, vitola: String?, country: String?) async throws {
        let userID = try await client.auth.session.user.id
        struct Pending: Encodable {
            let submitted_by: UUID
            let brand: String
            let line: String
            let vitola: String?
            let country: String?
        }
        try await client.from("cigars_pending")
            .insert(Pending(submitted_by: userID, brand: brand, line: line, vitola: vitola, country: country))
            .execute()
    }
}

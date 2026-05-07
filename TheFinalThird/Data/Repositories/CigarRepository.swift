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
    func featured(forDay date: Date) async throws -> Cigar?
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

    /// Returns a deterministic cigar for the given calendar day. The
    /// catalog rotates one entry per day-of-year, so the same date
    /// always yields the same cigar (until the catalog changes), and
    /// every day surfaces something different.
    ///
    /// Used by Home → Tonight's Pick when there's no live drop, no
    /// upcoming drop, and the user has no Usual cigar set.
    func featured(forDay date: Date = .now) async throws -> Cigar? {
        struct CountRow: Decodable, Sendable { let id: UUID }
        let allIDs: [CountRow] = try await client
            .from("cigars")
            .select("id")
            .eq("is_archived", value: false)
            .order("id", ascending: true)
            .execute()
            .value
        guard !allIDs.isEmpty else { return nil }

        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = (day - 1) % allIDs.count
        return try await fetch(id: allIDs[index].id)
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

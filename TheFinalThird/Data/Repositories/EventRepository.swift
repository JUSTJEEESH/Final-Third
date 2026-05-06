import Foundation
import Supabase

protocol EventRepository: Sendable {
    func upcoming(city: String?, limit: Int) async throws -> [LoungeEvent]
    func create(title: String, city: String?, locationName: String?, datetime: Date, cigarID: UUID?) async throws -> LoungeEvent
    func rsvp(eventID: UUID, status: EventRSVP.Status) async throws
}

struct LiveEventRepository: EventRepository {
    let client: SupabaseClient

    init(client: SupabaseClient = .live) { self.client = client }

    func upcoming(city: String?, limit: Int = 50) async throws -> [LoungeEvent] {
        var builder = client.from("events").select()
            .gte("datetime", value: ISO8601DateFormatter().string(from: .now))
        if let city { builder = builder.eq("city", value: city) }
        let dtos: [DTO.Event] = try await builder
            .order("datetime", ascending: true)
            .limit(limit)
            .execute().value
        return dtos.map { $0.toDomain() }
    }

    func create(title: String, city: String?, locationName: String?, datetime: Date, cigarID: UUID?) async throws -> LoungeEvent {
        let userID = try await client.auth.session.user.id
        struct Insert: Encodable {
            let creator_id: UUID
            let title: String
            let location_name: String?
            let city: String?
            let datetime: Date
            let cigar_id: UUID?
        }
        let dto: DTO.Event = try await client.from("events")
            .insert(Insert(creator_id: userID, title: title, location_name: locationName,
                           city: city, datetime: datetime, cigar_id: cigarID))
            .select().single().execute().value
        return dto.toDomain()
    }

    func rsvp(eventID: UUID, status: EventRSVP.Status) async throws {
        let userID = try await client.auth.session.user.id
        struct Upsert: Encodable {
            let event_id: UUID
            let user_id: UUID
            let status: String
        }
        try await client.from("event_rsvps")
            .upsert(Upsert(event_id: eventID, user_id: userID, status: status.rawValue),
                    onConflict: "event_id,user_id")
            .execute()
    }
}

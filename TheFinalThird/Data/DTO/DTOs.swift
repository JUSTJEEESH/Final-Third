import Foundation

/// Codable DTOs that mirror Supabase row shapes (snake_case columns).
/// Mapped to domain models via `Data/Mapping/*`.
enum DTO {}

extension DTO {
    struct Profile: Codable, Sendable {
        let id: UUID
        let email: String?
        let display_name: String
        let handle: String?
        let avatar_url: String?
        let bio: String?
        let country: String?
        let city: String?
        let is_local: Bool
        let is_premium: Bool
        let audio_theme: String?
        let voice_enabled: Bool
        let ghost_mode_default: Bool
        let notif_prefs: NotifPrefs?
        let timezone: String?
        let created_at: Date
    }

    struct NotifPrefs: Codable, Sendable {
        let the_usual: Bool?
        let arrival_signal: Bool?
        let drops: Bool?
        let events: Bool?
    }

    struct Cigar: Codable, Sendable {
        let id: UUID
        let brand: String
        let line: String
        let vitola: String?
        let country: String?
        let wrapper: String?
        let binder: String?
        let filler: String?
        let ring_gauge: Int?
        let length: Double?
        let strength: Int?
        let flavor_notes: [String]?
        let origin_story: String?
        let affiliate_link: String?
        let image_url: String?
        let fun_fact: String?
    }

    struct Drink: Codable, Sendable {
        let id: UUID
        let brand: String?
        let name: String
        let category: String
        let subtype: String?
        let image_url: String?
    }

    struct Room: Codable, Sendable {
        let id: UUID
        let owner_id: UUID?
        let name: String
        let description: String?
        let theme: String?
        let is_private: Bool
        let audio_theme: String?
        let created_at: Date
    }

    struct Message: Codable, Sendable {
        let id: UUID
        let room_id: UUID
        let sender_id: UUID?
        let body: String
        let edited_at: Date?
        let deleted_at: Date?
        let created_at: Date
    }

    struct MessageInsert: Codable, Sendable {
        let id: UUID
        let room_id: UUID
        let sender_id: UUID
        let body: String
    }

    struct Session: Codable, Sendable {
        let id: UUID
        let user_id: UUID
        let room_id: UUID?
        let cigar_id: UUID?
        let drink_id: UUID?
        let started_at: Date
        let ended_at: Date?
        let duration_minutes: Int?
        let flavor_rating: Int?
        let draw_rating: Int?
        let overall_rating: Int?
        let would_smoke_again: Bool?
        let notes: String?
        let mood_score: Int?
        let unwind_success: Bool?
        let lighting_method: String?
        let is_ghost: Bool
    }

    struct Usual: Codable, Sendable {
        let id: UUID
        let user_id: UUID
        let preferred_time: String?     // "HH:MM"
        let cigar_id: UUID?
        let drink_id: UUID?
        let enabled: Bool
        let streak_count: Int
        let last_completed_at: Date?
    }

    struct Connection: Codable, Sendable {
        let id: UUID
        let requester_id: UUID
        let addressee_id: UUID
        let status: String
        let created_at: Date
    }

    struct Event: Codable, Sendable {
        let id: UUID
        let creator_id: UUID?
        let title: String
        let location_name: String?
        let city: String?
        let datetime: Date?
        let cigar_id: UUID?
    }

    struct Drop: Codable, Sendable {
        let id: UUID
        let cigar_id: UUID
        let room_id: UUID?
        let hero_copy: String?
        let starts_at: Date
        let ends_at: Date
    }
}

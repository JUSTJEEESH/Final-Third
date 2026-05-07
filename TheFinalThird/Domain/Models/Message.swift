import Foundation

struct Message: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let roomID: UUID
    let senderID: UUID?
    var body: String
    var editedAt: Date?
    var deletedAt: Date?
    let createdAt: Date
    /// `.user` is a normal chat message. The other cases are system
    /// events posted by the session lifecycle and surface as gold-
    /// accented rows in the chat with a brief ember pulse on first
    /// appearance — they're how the room reacts to your ritual.
    var kind: Kind = .user
    /// Typed payload for system messages. Nil for `.user`.
    var payload: SystemPayload?
    /// Local-only flags (not persisted server-side).
    var pendingState: PendingState = .synced

    enum Kind: String, Sendable, Codable, Hashable {
        case user
        case arrival
        case departure
        case move
    }

    enum PendingState: Sendable, Codable, Hashable {
        case synced
        case pending
        case failed(reason: String)
    }
}

/// Metadata that travels with arrival/departure/move messages. Stored
/// as `messages.payload jsonb` server-side. Every field is optional —
/// the renderer fills in what it can:
///   • arrival   → cigarBrand/cigarLine, drinkName
///   • departure → durationMinutes, rating (Patron only)
///   • move      → fromRoomName / toRoomName
struct SystemPayload: Hashable, Sendable, Codable {
    var cigarBrand: String?
    var cigarLine: String?
    var drinkName: String?
    var durationMinutes: Int?
    var rating: Int?
    var fromRoomName: String?
    var toRoomName: String?
    /// Cached display name + avatar of the actor at post time so
    /// arrivals/departures still render correctly if the user later
    /// changes their profile.
    var displayName: String?
    var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case cigarBrand = "cigar_brand"
        case cigarLine = "cigar_line"
        case drinkName = "drink_name"
        case durationMinutes = "duration_minutes"
        case rating
        case fromRoomName = "from_room_name"
        case toRoomName = "to_room_name"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}

struct MessageReaction: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let messageID: UUID
    let userID: UUID
    let reaction: Reaction
    let createdAt: Date

    enum Reaction: String, CaseIterable, Sendable, Codable {
        case toast, fire, smoke, salute, love

        var glyph: String {
            switch self {
            case .toast: return "🥃"
            case .fire: return "🔥"
            case .smoke: return "💨"
            case .salute: return "🫡"
            case .love: return "❤️"
            }
        }
    }
}

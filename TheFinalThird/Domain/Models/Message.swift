import Foundation

struct Message: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let roomID: UUID
    let senderID: UUID?
    var body: String
    var editedAt: Date?
    var deletedAt: Date?
    let createdAt: Date
    /// Local-only flags (not persisted server-side).
    var pendingState: PendingState = .synced

    enum PendingState: Sendable, Codable, Hashable {
        case synced
        case pending
        case failed(reason: String)
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

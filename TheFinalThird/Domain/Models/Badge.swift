import Foundation

struct Badge: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var code: String
    var name: String
    var description: String
}

struct UserBadge: Hashable, Sendable, Codable {
    let userID: UUID
    let badgeID: UUID
    let earnedAt: Date
}

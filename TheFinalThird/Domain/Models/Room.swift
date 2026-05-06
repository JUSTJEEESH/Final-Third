import Foundation

struct Room: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var ownerID: UUID?
    var name: String
    var description: String?
    var theme: String?
    var isPrivate: Bool
    var audioTheme: AudioTheme?
    var createdAt: Date
}

struct RoomMember: Hashable, Sendable, Codable {
    let roomID: UUID
    let userID: UUID
    var role: Role
    var joinedAt: Date

    enum Role: String, Sendable, Codable { case owner, moderator, member }
}

struct RoomPresence: Hashable, Sendable, Codable {
    let roomID: UUID
    let userID: UUID
    var displayName: String
    var avatarURL: URL?
    var isGhost: Bool
    var joinedAt: Date
    var lastSeenAt: Date
}

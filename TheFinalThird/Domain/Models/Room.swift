import Foundation

struct Room: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var ownerID: UUID?
    var name: String
    var description: String?
    var theme: String?
    var isPrivate: Bool
    var audioTheme: AudioTheme?
    var mode: Mode = .chat
    var createdAt: Date

    /// Voice rooms are Patron-only. Chat rooms are open to everyone.
    /// The picker shows voice rooms with a gold lock for free users.
    enum Mode: String, Sendable, Codable { case chat, voice }
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

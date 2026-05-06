import Foundation

struct Profile: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var email: String?
    var displayName: String
    var handle: String?
    var avatarURL: URL?
    var bio: String?
    var city: String?
    var isHondurasLocal: Bool
    var isPremium: Bool
    var audioTheme: AudioTheme?
    var voiceEnabled: Bool
    var ghostModeDefault: Bool
    var notificationPrefs: NotificationPrefs
    var quietHoursStart: TimeOfDay?
    var quietHoursEnd: TimeOfDay?
    var timezone: String?
    var createdAt: Date

    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

struct NotificationPrefs: Hashable, Sendable, Codable {
    var theUsual: Bool = true
    var arrivalSignal: Bool = true
    var drops: Bool = true
    var events: Bool = true

    static let `default` = NotificationPrefs()
}

struct TimeOfDay: Hashable, Sendable, Codable {
    var hour: Int
    var minute: Int
}

enum AudioTheme: String, CaseIterable, Sendable, Codable {
    case loungeMurmur = "lounge_murmur"
    case jazz
    case lofi
    case rain
    case fireplace

    var displayName: String {
        switch self {
        case .loungeMurmur: return "Lounge Murmur"
        case .jazz: return "Jazz"
        case .lofi: return "Lo-fi"
        case .rain: return "Rain"
        case .fireplace: return "Fireplace"
        }
    }
}

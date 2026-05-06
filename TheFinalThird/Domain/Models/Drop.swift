import Foundation

struct CigarDrop: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var cigarID: UUID
    var roomID: UUID?
    var heroCopy: String?
    var startsAt: Date
    var endsAt: Date

    var isLive: Bool {
        let now = Date.now
        return now >= startsAt && now < endsAt
    }
}

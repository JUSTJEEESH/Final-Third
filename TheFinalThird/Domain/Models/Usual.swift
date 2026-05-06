import Foundation

struct Usual: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var userID: UUID
    var preferredTime: TimeOfDay?
    var cigarID: UUID?
    var drinkID: UUID?
    var enabled: Bool
    var streakCount: Int
    var lastCompletedAt: Date?
}

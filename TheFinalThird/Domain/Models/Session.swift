import Foundation

struct Session: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var userID: UUID
    var roomID: UUID?
    var cigarID: UUID?
    var drinkID: UUID?
    var startedAt: Date
    var endedAt: Date?
    var durationMinutes: Int?
    var flavorRating: Int?
    var drawRating: Int?
    var overallRating: Int?
    var wouldSmokeAgain: Bool?
    var notes: String?
    var moodScore: Int?
    var unwindSuccess: Bool?
    var lightingMethod: LightingMethod?
    var isGhost: Bool

    enum LightingMethod: String, CaseIterable, Sendable, Codable {
        case match
        case torch
        case cedar
        case softFlame = "soft_flame"

        var displayName: String {
            switch self {
            case .match: return "Match"
            case .torch: return "Torch"
            case .cedar: return "Cedar Spill"
            case .softFlame: return "Soft Flame"
            }
        }
    }

    /// Burn-time thirds — used to drive the final-third moment.
    enum Third { case first, middle, final }

    func currentThird(now: Date = .now) -> Third? {
        guard let endedAt else {
            // estimate using a typical hour-long burn, capped by elapsed
            let elapsed = now.timeIntervalSince(startedAt)
            let est: TimeInterval = 60 * 60
            let frac = min(max(elapsed / est, 0), 1)
            return third(from: frac)
        }
        let total = endedAt.timeIntervalSince(startedAt)
        guard total > 0 else { return nil }
        let frac = min(max(now.timeIntervalSince(startedAt) / total, 0), 1)
        return third(from: frac)
    }

    private func third(from frac: Double) -> Third {
        switch frac {
        case ..<0.34: return .first
        case ..<0.67: return .middle
        default: return .final
        }
    }
}

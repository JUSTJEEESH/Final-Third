import Foundation
import Observation

@MainActor
@Observable
final class JournalViewModel {
    private(set) var sessions: [Session] = []
    private(set) var cigarsByID: [UUID: Cigar] = [:]
    private(set) var isLoading = false
    private(set) var error: String?

    /// Free tier shows only the most recent 30; older rows are gated.
    let freeLimit = 30

    private let userID: UUID
    private let sessionsRepo: SessionRepository
    private let cigarsRepo: CigarRepository
    private let entitlements: EntitlementService

    init(
        userID: UUID,
        sessions: SessionRepository = LiveSessionRepository(),
        cigars: CigarRepository = LiveCigarRepository(),
        entitlements: EntitlementService
    ) {
        self.userID = userID
        self.sessionsRepo = sessions
        self.cigarsRepo = cigars
        self.entitlements = entitlements
    }

    var visibleSessions: [Session] {
        guard !entitlements.isPremium else { return sessions }
        return Array(sessions.prefix(freeLimit))
    }

    var hiddenCount: Int {
        guard !entitlements.isPremium else { return 0 }
        return max(0, sessions.count - freeLimit)
    }

    func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            sessions = try await sessionsRepo.recent(userID: userID, limit: 200)
            await hydrateCigars()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func hydrateCigars() async {
        let ids = Set(sessions.compactMap(\.cigarID))
        await withTaskGroup(of: (UUID, Cigar?).self) { group in
            for id in ids where cigarsByID[id] == nil {
                group.addTask { [cigarsRepo] in
                    let cigar = try? await cigarsRepo.fetch(id: id)
                    return (id, cigar)
                }
            }
            for await (id, cigar) in group {
                if let cigar { cigarsByID[id] = cigar }
            }
        }
    }

    // MARK: Stats

    var totalSessions: Int { sessions.filter { $0.endedAt != nil }.count }

    var totalMinutes: Int {
        sessions.compactMap(\.durationMinutes).reduce(0, +)
    }

    var favoriteCigar: Cigar? {
        let counts = Dictionary(grouping: sessions.compactMap(\.cigarID), by: { $0 })
            .mapValues(\.count)
        let topID = counts.max { $0.value < $1.value }?.key
        return topID.flatMap { cigarsByID[$0] }
    }

    var preferredStrength: Int? {
        let strengths = sessions.compactMap { $0.cigarID.flatMap { cigarsByID[$0]?.strength } }
        guard !strengths.isEmpty else { return nil }
        let avg = Double(strengths.reduce(0, +)) / Double(strengths.count)
        return Int(avg.rounded())
    }

    var weeklyRecap: WeeklyRecap {
        let cal = Calendar.current
        let weekStart = cal.date(byAdding: .day, value: -7, to: .now) ?? .now
        let recent = sessions.filter { $0.startedAt >= weekStart }
        let durations = recent.compactMap(\.durationMinutes)
        let avgMinutes = durations.isEmpty ? 0 :
            Int(Double(durations.reduce(0, +)) / Double(durations.count))
        return WeeklyRecap(sessionCount: recent.count, averageMinutes: avgMinutes)
    }
}

struct WeeklyRecap: Sendable {
    let sessionCount: Int
    let averageMinutes: Int
}

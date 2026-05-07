import Foundation
import Testing
@testable import TheFinalThird

@Suite("Journal weekly recap + stats")
@MainActor
struct JournalStatsTests {
    private func session(daysAgo: Int, minutes: Int?) -> Session {
        let started = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let ended = minutes.map { started.addingTimeInterval(TimeInterval($0 * 60)) }
        return Session(
            id: UUID(), userID: UUID(),
            roomID: nil, cigarID: nil, drinkID: nil,
            startedAt: started, endedAt: ended,
            durationMinutes: minutes,
            flavorRating: nil, drawRating: nil, overallRating: nil,
            wouldSmokeAgain: nil, notes: nil, moodScore: nil,
            unwindSuccess: nil, lightingMethod: nil, isGhost: false
        )
    }

    @Test("Weekly recap counts only sessions in the last 7 days")
    func weeklyRecapWindow() async {
        let vm = JournalViewModel(
            userID: UUID(),
            sessions: StubSessionRepo(sessions: [
                session(daysAgo: 1, minutes: 50),
                session(daysAgo: 2, minutes: 70),
                session(daysAgo: 8, minutes: 60), // outside window
            ]),
            cigars: StubCigarRepo(),
            entitlements: EntitlementService()
        )
        await vm.load()
        #expect(vm.weeklyRecap.sessionCount == 2)
        #expect(vm.weeklyRecap.averageMinutes == 60)
    }

    @Test("Free tier hides sessions beyond the 30-row limit")
    func freeTierLimit() async {
        let many = (0 ..< 35).map { i in session(daysAgo: i, minutes: 30) }
        let vm = JournalViewModel(
            userID: UUID(),
            sessions: StubSessionRepo(sessions: many),
            cigars: StubCigarRepo(),
            entitlements: EntitlementService()
        )
        await vm.load()
        #expect(vm.visibleSessions.count == 30)
        #expect(vm.hiddenCount == 5)
    }
}

// MARK: Stubs

private struct StubSessionRepo: SessionRepository, @unchecked Sendable {
    var sessions: [Session] = []
    func recent(userID: UUID, limit: Int) async throws -> [Session] { sessions }
    func fetch(id: UUID) async throws -> Session {
        if let s = sessions.first(where: { $0.id == id }) { return s }
        throw AppError.notFound(entity: "Session")
    }
    func start(userID: UUID, roomID: UUID?, cigarID: UUID?, drinkID: UUID?,
               lightingMethod: Session.LightingMethod?, isGhost: Bool) async throws -> Session {
        fatalError("unused in tests")
    }
    func finish(_ session: Session) async throws -> Session { session }
    func saveSummary(sessionID: UUID, flavor: Int, draw: Int, overall: Int,
                     wouldSmokeAgain: Bool, mood: Int, unwind: Bool, notes: String?) async throws {}
    func delete(id: UUID) async throws {}
}

private struct StubCigarRepo: CigarRepository {
    func search(_ filters: CigarFilters, limit: Int) async throws -> [Cigar] { [] }
    func fetch(id: UUID) async throws -> Cigar {
        Cigar(id: id, brand: "x", line: "y", vitola: nil, country: nil,
              wrapper: nil, binder: nil, filler: nil, ringGauge: nil, length: nil,
              strength: nil, flavorNotes: [], originStory: nil, affiliateLink: nil,
              imageURL: nil, funFact: nil)
    }
    func featured(forDay date: Date) async throws -> Cigar? { nil }
    func submitPending(brand: String, line: String, vitola: String?, country: String?) async throws {}
}

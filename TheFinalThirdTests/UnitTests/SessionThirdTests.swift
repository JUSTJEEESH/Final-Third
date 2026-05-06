import Foundation
import Testing
@testable import TheFinalThird

@Suite("Session.currentThird")
struct SessionThirdTests {
    private func session(start: Date, end: Date? = nil) -> Session {
        Session(
            id: UUID(), userID: UUID(),
            roomID: nil, cigarID: nil, drinkID: nil,
            startedAt: start, endedAt: end,
            durationMinutes: nil,
            flavorRating: nil, drawRating: nil, overallRating: nil,
            wouldSmokeAgain: nil, notes: nil, moodScore: nil,
            unwindSuccess: nil, lightingMethod: nil, isGhost: false
        )
    }

    @Test("Closed session: first third before 33%")
    func closedSessionFirstThird() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 60 * 60)        // 1h
        let s = session(start: start, end: end)
        let now = Date(timeIntervalSince1970: 60 * 10)        // 10 min in
        #expect(s.currentThird(now: now) == .first)
    }

    @Test("Closed session: middle around 50%")
    func closedSessionMiddle() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 60 * 60)
        let s = session(start: start, end: end)
        let now = Date(timeIntervalSince1970: 60 * 30)        // 30 min in
        #expect(s.currentThird(now: now) == .middle)
    }

    @Test("Closed session: final third after 67%")
    func closedSessionFinal() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 60 * 60)
        let s = session(start: start, end: end)
        let now = Date(timeIntervalSince1970: 60 * 50)        // 50 min in
        #expect(s.currentThird(now: now) == .final)
    }

    @Test("Open session estimates against 60 minutes")
    func openSessionEstimates() {
        let start = Date(timeIntervalSince1970: 0)
        let s = session(start: start, end: nil)
        let oneMin = s.currentThird(now: Date(timeIntervalSince1970: 60))
        let halfHour = s.currentThird(now: Date(timeIntervalSince1970: 60 * 30))
        let fiftyMin = s.currentThird(now: Date(timeIntervalSince1970: 60 * 50))
        #expect(oneMin == .first)
        #expect(halfHour == .middle)
        #expect(fiftyMin == .final)
    }

    @Test("Open session caps at final past estimate")
    func openSessionCaps() {
        let start = Date(timeIntervalSince1970: 0)
        let s = session(start: start, end: nil)
        let twoHours = s.currentThird(now: Date(timeIntervalSince1970: 60 * 60 * 2))
        #expect(twoHours == .final)
    }
}

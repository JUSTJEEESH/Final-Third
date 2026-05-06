import Foundation
import Observation

@MainActor
@Observable
final class SessionViewModel {
    enum Phase: Equatable {
        case selectingCigar
        case selectingDrink
        case lighting
        case active
        case summary
        case finished
    }

    var phase: Phase = .selectingCigar
    var cigar: Cigar?
    var drink: Drink?
    var lightingMethod: Session.LightingMethod = .match
    var session: Session?
    var lastThird: Session.Third?

    // Summary
    var flavor: Int = 3
    var draw: Int = 3
    var overall: Int = 3
    var wouldSmokeAgain: Bool = true
    var mood: Int = 5
    var unwind: Bool = true
    var notes: String = ""

    private let userID: UUID
    private let roomID: UUID?
    private let isGhost: Bool
    private let sessions: SessionRepository
    private let analytics: AnalyticsService
    private var tickerTask: Task<Void, Never>?

    init(
        userID: UUID, roomID: UUID?, isGhost: Bool,
        sessions: SessionRepository = LiveSessionRepository(),
        analytics: AnalyticsService
    ) {
        self.userID = userID
        self.roomID = roomID
        self.isGhost = isGhost
        self.sessions = sessions
        self.analytics = analytics
    }

    func selectCigar(_ cigar: Cigar) {
        self.cigar = cigar
        phase = .selectingDrink
    }

    func selectDrink(_ drink: Drink) {
        self.drink = drink
        phase = .lighting
    }

    func startSession() async {
        do {
            session = try await sessions.start(
                userID: userID, roomID: roomID,
                cigarID: cigar?.id, drinkID: drink?.id,
                lightingMethod: lightingMethod, isGhost: isGhost
            )
            analytics.track(.sessionStarted(cigarID: cigar?.id, drinkID: drink?.id))
            phase = .active
            startBurnTimer()
        } catch {
            // surface in UI; for now keep it simple
        }
    }

    func endSession() async {
        guard let session else { return }
        tickerTask?.cancel()
        do {
            self.session = try await sessions.finish(session)
            phase = .summary
        } catch {
            phase = .summary
        }
    }

    func saveSummary() async {
        guard let session else { return }
        do {
            try await sessions.saveSummary(
                sessionID: session.id,
                flavor: flavor, draw: draw, overall: overall,
                wouldSmokeAgain: wouldSmokeAgain,
                mood: mood, unwind: unwind,
                notes: notes.isEmpty ? nil : notes
            )
            analytics.track(.sessionEnded(
                duration: session.durationMinutes ?? 0,
                rated: true
            ))
            phase = .finished
        } catch {
            phase = .finished
        }
    }

    private func startBurnTimer() {
        tickerTask?.cancel()
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self else { break }
                guard let session = self.session else { break }
                let third = session.currentThird()
                if third != self.lastThird {
                    self.lastThird = third
                    if third == .final {
                        HapticsService.shared.playFinalThirdPattern()
                        self.analytics.track(.finalThirdMoment(roomID: self.roomID))
                    }
                }
            }
        }
    }
}

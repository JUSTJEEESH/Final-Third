import Foundation
import Observation

@MainActor
@Observable
final class SessionViewModel {
    enum Phase: Equatable {
        case selectingCigar
        case selectingDrink
        case selectingLightingMethod
        case lighting
        /// Post-ceremony, pre-active. The "Where are you sitting?"
        /// picker owns the screen here. Resolves into either a room
        /// or solo via `chooseRoom(_:)`.
        case choosingRoom
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
    /// Set by `chooseRoom(_:)` before the session row is created in
    /// Postgres so the row starts with the correct `room_id`. Stays
    /// nil for solo sessions.
    private(set) var chosenRoom: Room?

    // Summary
    var flavor: Int = 3
    var draw: Int = 3
    var overall: Int = 3
    var wouldSmokeAgain: Bool = true
    var mood: Int = 5
    var unwind: Bool = true
    var notes: String = ""

    private let userID: UUID
    /// May be set at construction (Path B: lit up from inside a room)
    /// or assigned by `chooseRoom(_:)` after the ceremony (Path A).
    private var roomID: UUID?
    private let isGhost: Bool
    private let sessions: SessionRepository
    private let messages: MessageRepository
    private let profiles: ProfileRepository
    private let analytics: AnalyticsService
    private var tickerTask: Task<Void, Never>?

    init(
        userID: UUID, room: Room?, isGhost: Bool,
        analytics: AnalyticsService,
        sessions: SessionRepository = LiveSessionRepository(),
        messages: MessageRepository = LiveMessageRepository(),
        profiles: ProfileRepository = LiveProfileRepository()
    ) {
        self.userID = userID
        self.roomID = room?.id
        self.chosenRoom = room
        self.isGhost = isGhost
        self.sessions = sessions
        self.messages = messages
        self.profiles = profiles
        self.analytics = analytics
    }

    func selectCigar(_ cigar: Cigar) {
        self.cigar = cigar
        phase = .selectingDrink
    }

    func selectDrink(_ drink: Drink) {
        self.drink = drink
        phase = .selectingLightingMethod
    }

    func skipDrink() {
        drink = nil
        phase = .selectingLightingMethod
    }

    func chooseLightingMethod(_ method: Session.LightingMethod) {
        lightingMethod = method
        phase = .lighting
    }

    /// Called from the LightingCeremonyView's onComplete handler.
    /// Path A (no preselected room) → doorway sheet. Path B (lit up
    /// from inside a room — `chosenRoom` already set) skips the
    /// picker and goes straight to the burn.
    func ceremonyCompleted() {
        if chosenRoom != nil {
            Task { await startSession() }
        } else {
            phase = .choosingRoom
        }
    }

    /// Resolves the doorway sheet. Pass `nil` for "Stay solo" — the
    /// session row is still created (we just leave `room_id` null).
    /// Otherwise the chosen room is recorded and (best-effort) the
    /// user is enrolled in `room_members` so they show up in the
    /// room's chat alongside the cigar.
    func chooseRoom(_ room: Room?, rooms: RoomRepository = LiveRoomRepository()) async {
        chosenRoom = room
        roomID = room?.id
        if let room {
            // Best-effort join. We don't want to block the session
            // start on a room_members write — if it fails we'll heal
            // the next time the user opens the room.
            try? await rooms.join(roomID: room.id)
        }
        await startSession()
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
            // Fire the arrival event so the room reacts in real time.
            // Best-effort — a failed RPC shouldn't tank the burn.
            await postArrivalIfNeeded()
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
        // Fire the departure event after we have the final duration.
        // Rating is added in `saveSummary` if the user gave one.
        await postDepartureIfNeeded(rating: nil)
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

    // MARK: - System events

    /// Post "X has lit up" into the chosen room. Suppressed for solo
    /// (no roomID) and ghost (privacy guarantee). Snapshots the
    /// user's display name + avatar so the row renders correctly even
    /// if the profile changes later.
    private func postArrivalIfNeeded() async {
        guard let roomID, !isGhost else { return }
        let snapshot = await profileSnapshot()
        let payload = SystemPayload(
            cigarBrand: cigar?.brand,
            cigarLine: cigar?.line,
            drinkName: drink?.name,
            durationMinutes: nil,
            rating: nil,
            fromRoomName: nil,
            toRoomName: nil,
            displayName: snapshot.name,
            avatarURL: snapshot.avatar
        )
        try? await messages.postSystem(roomID: roomID, kind: .arrival, payload: payload)
    }

    /// Post "X stepped out · 47 min" into the chosen room. Same gates
    /// as arrival. Rating shows only when the actor is a Patron and
    /// passed an `overall` rating ≥ 4 (the implicit endorsement).
    private func postDepartureIfNeeded(rating: Int?) async {
        guard let roomID, !isGhost else { return }
        let snapshot = await profileSnapshot()
        let payload = SystemPayload(
            cigarBrand: cigar?.brand,
            cigarLine: cigar?.line,
            drinkName: drink?.name,
            durationMinutes: session?.durationMinutes,
            rating: rating,
            fromRoomName: nil,
            toRoomName: nil,
            displayName: snapshot.name,
            avatarURL: snapshot.avatar
        )
        try? await messages.postSystem(roomID: roomID, kind: .departure, payload: payload)
    }

    private func profileSnapshot() async -> (name: String, avatar: String?) {
        if let p = try? await profiles.fetch(id: userID) {
            return (p.displayName, p.avatarURL?.absoluteString)
        }
        return ("Someone", nil)
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

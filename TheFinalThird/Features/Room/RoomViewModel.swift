import Foundation
import Observation

@MainActor
@Observable
final class RoomViewModel {
    let roomID: UUID
    var room: Room?
    var messages: [Message] = []
    var presence: [RoomPresence] = []
    var isGhost = false
    var draft = ""
    var error: String?

    /// Live smokers in this room, keyed by `userID`. Refreshed on
    /// enter and on a 30-second loop so the cigar chips next to
    /// avatars stay current. Sources from the same `room_live_now`
    /// RPC the doorway sheet uses.
    var smokersByUser: [UUID: LiveNowSummary.Smoker] = [:]
    private var smokerPollTask: Task<Void, Never>?

    // Voice + ambient (M18)
    var voiceJoined = false
    var ambientTheme: AudioTheme?

    private let rooms: RoomRepository
    private let messagesRepo: MessageRepository
    private let realtime: RealtimeService
    private let voice: VoiceService
    private let audio: AudioEngine
    private let analytics: AnalyticsService
    private let voiceTokenProvider: RoomVoiceTokenProvider
    private var streamTask: Task<Void, Never>?
    private var earliestLoaded: Date?

    init(
        roomID: UUID,
        rooms: RoomRepository = LiveRoomRepository(),
        messages: MessageRepository = LiveMessageRepository(),
        realtime: RealtimeService,
        voice: VoiceService,
        audio: AudioEngine,
        analytics: AnalyticsService,
        voiceTokenProvider: RoomVoiceTokenProvider = RoomVoiceTokenProvider()
    ) {
        self.roomID = roomID
        self.rooms = rooms
        self.messagesRepo = messages
        self.realtime = realtime
        self.voice = voice
        self.audio = audio
        self.analytics = analytics
        self.voiceTokenProvider = voiceTokenProvider
    }

    func enter(asGhost: Bool) async {
        isGhost = asGhost
        do {
            room = try await rooms.fetch(id: roomID)
            try await rooms.join(roomID: roomID)
            try await rooms.setPresence(roomID: roomID, isGhost: asGhost)
            messages = try await messagesRepo.page(roomID: roomID, before: nil, limit: 50)
            earliestLoaded = messages.first?.createdAt
            analytics.track(.roomJoined(roomID: roomID, ghost: asGhost))
            startListening()
            await refreshSmokers()
            startSmokerPolling()

            // Ambient mix follows the room's saved theme.
            ambientTheme = room?.audioTheme
            audio.setTheme(ambientTheme)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func leave() async {
        streamTask?.cancel()
        smokerPollTask?.cancel()
        await voice.leave()
        audio.setTheme(nil)
        voiceJoined = false
        try? await rooms.leave(roomID: roomID)
        analytics.track(.roomLeft(roomID: roomID))
    }

    // MARK: Refresh

    /// Pull-to-refresh-style refetch of the latest page of messages.
    /// Used to surface freshly-posted system events (arrival /
    /// departure / move) until the realtime stream is wired up. Cheap
    /// because the page is capped at 50 rows.
    func refreshMessages() async {
        guard let fresh = try? await messagesRepo.page(roomID: roomID, before: nil, limit: 50) else { return }
        // Merge — keep any pending local sends that haven't synced yet.
        let pendingLocal = messages.filter {
            if case .pending = $0.pendingState { return true }
            if case .failed = $0.pendingState { return true }
            return false
        }
        var merged = fresh
        for p in pendingLocal where !merged.contains(where: { $0.id == p.id }) {
            merged.append(p)
        }
        messages = merged
    }

    // MARK: Smokers

    /// One-shot refresh of who's currently lit up in this room. The
    /// RPC filters out ghost sessions server-side.
    func refreshSmokers() async {
        let map = (try? await rooms.liveNow(roomIDs: [roomID])) ?? [:]
        let summary = map[roomID]
        var byUser: [UUID: LiveNowSummary.Smoker] = [:]
        for s in summary?.smokers ?? [] { byUser[s.userID] = s }
        smokersByUser = byUser
    }

    private func startSmokerPolling() {
        smokerPollTask?.cancel()
        smokerPollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { break }
                await self?.refreshSmokers()
            }
        }
    }

    // MARK: Voice

    func joinVoice() async {
        guard !isGhost else { return }       // ghost mode forces silence
        guard !voiceJoined else { return }
        do {
            try await voice.join(
                roomID: roomID,
                asSpeaker: true,
                tokenProvider: { [voiceTokenProvider] roomID in
                    try await voiceTokenProvider.token(forRoom: roomID)
                }
            )
            voiceJoined = true
        } catch {
            self.error = "Voice unavailable: \(error.localizedDescription)"
        }
    }

    func setTransmitting(_ on: Bool) async {
        await voice.setTransmitting(on)
        // Duck ambient under voice; restore when released.
        audio.duck(on)
        if !on {
            analytics.track(.voiceTransmitted(roomID: roomID, durationMs: 0))
        }
    }

    func setAmbient(_ theme: AudioTheme?) {
        ambientTheme = theme
        audio.setTheme(theme)
    }

    func loadOlder() async {
        guard let earliestLoaded else { return }
        do {
            let older = try await messagesRepo.page(roomID: roomID, before: earliestLoaded, limit: 50)
            messages.insert(contentsOf: older, at: 0)
            self.earliestLoaded = older.first?.createdAt ?? earliestLoaded
        } catch {
            // ignore — older history is best-effort
        }
    }

    func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        draft = ""

        let optimistic = Message(
            id: UUID(),
            roomID: roomID,
            senderID: nil,
            body: body,
            editedAt: nil,
            deletedAt: nil,
            createdAt: .now,
            pendingState: .pending
        )
        messages.append(optimistic)

        do {
            let saved = try await messagesRepo.send(roomID: roomID, body: body, clientID: optimistic.id)
            replace(id: optimistic.id, with: saved)
            analytics.track(.messageSent(roomID: roomID))
        } catch {
            mark(id: optimistic.id, failedReason: error.localizedDescription)
        }
    }

    private func startListening() {
        streamTask = Task { [weak self, realtime, roomID] in
            guard let self else { return }
            for await event in await realtime.subscribe(roomID: roomID) {
                self.apply(event)
            }
        }
    }

    private func apply(_ event: RealtimeService.Event) {
        switch event {
        case .message(let m):
            if !messages.contains(where: { $0.id == m.id }) { messages.append(m) }
        case .messageEdited(let m):
            replace(id: m.id, with: m)
        case .messageDeleted(let id):
            messages.removeAll { $0.id == id }
        case .presenceJoined(let p):
            if !presence.contains(where: { $0.userID == p.userID }) { presence.append(p) }
            if !p.isGhost { HapticsService.shared.playArrivalSignal() }
        case .presenceLeft(let userID, _):
            presence.removeAll { $0.userID == userID }
        case .reactionAdded, .reactionRemoved:
            break
        }
    }

    private func replace(id: UUID, with new: Message) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx] = new
        }
    }

    private func mark(id: UUID, failedReason: String) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].pendingState = .failed(reason: failedReason)
        }
    }
}

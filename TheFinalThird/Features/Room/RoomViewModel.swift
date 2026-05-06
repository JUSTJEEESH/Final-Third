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

    private let rooms: RoomRepository
    private let messagesRepo: MessageRepository
    private let realtime: RealtimeService
    private let analytics: AnalyticsService
    private var streamTask: Task<Void, Never>?
    private var earliestLoaded: Date?

    init(
        roomID: UUID,
        rooms: RoomRepository = LiveRoomRepository(),
        messages: MessageRepository = LiveMessageRepository(),
        realtime: RealtimeService,
        analytics: AnalyticsService
    ) {
        self.roomID = roomID
        self.rooms = rooms
        self.messagesRepo = messages
        self.realtime = realtime
        self.analytics = analytics
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
        } catch {
            self.error = error.localizedDescription
        }
    }

    func leave() async {
        streamTask?.cancel()
        try? await rooms.leave(roomID: roomID)
        analytics.track(.roomLeft(roomID: roomID))
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

import Foundation
import OrderedCollections
import Supabase

/// Manages Supabase Realtime channels for chat, presence, and reactions.
///
/// NOTE: stubbed pending verification of the resolved supabase-swift API
/// surface (postgresChange / presenceChange shapes shifted between minor
/// versions). The `subscribe(roomID:)` method returns a finishing
/// AsyncStream so callers compile and run; the streaming chat updates +
/// presence join/leave events will be wired in once the SDK is pinned.
/// REST-based message paging via `MessageRepository.page` still works.
actor RealtimeService {
    enum Event: Sendable {
        case message(Message)
        case messageEdited(Message)
        case messageDeleted(UUID)
        case reactionAdded(MessageReaction)
        case reactionRemoved(MessageReaction)
        case presenceJoined(RoomPresence)
        case presenceLeft(userID: UUID, roomID: UUID)
    }

    private let client: SupabaseClient
    private var subscribers: [String: Int] = [:]
    private var recentMessageIDs: [String: OrderedSet<UUID>] = [:]
    private let dedupeWindow = 500

    init(client: SupabaseClient = .live) {
        self.client = client
    }

    /// Returns an AsyncStream the caller drives for the lifetime of a room
    /// view. Currently terminates immediately — see file note above.
    func subscribe(roomID: UUID) -> AsyncStream<Event> {
        let topic = "room:\(roomID.uuidString)"
        subscribers[topic, default: 0] += 1

        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in await self?.release(topic: topic) }
            }
            // No live updates yet — finish the stream so consumers don't hang.
            continuation.finish()
        }
    }

    private func release(topic: String) async {
        subscribers[topic, default: 0] -= 1
        if subscribers[topic] ?? 0 <= 0 {
            subscribers[topic] = nil
            recentMessageIDs[topic] = nil
        }
    }

    /// Reserved for the dedupe path once realtime is wired up. Keeps the
    /// algorithm available and unit-testable today.
    func markSeen(_ id: UUID, in topic: String) -> Bool {
        var set = recentMessageIDs[topic] ?? OrderedSet<UUID>()
        if set.contains(id) { return false }
        set.append(id)
        if set.count > dedupeWindow {
            set.removeFirst(set.count - dedupeWindow)
        }
        recentMessageIDs[topic] = set
        return true
    }
}

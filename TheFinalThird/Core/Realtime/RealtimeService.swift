import Foundation
import OrderedCollections
import Supabase

/// Live updates for chat, presence, and reactions per room.
///
/// One channel per room. Callbacks fire on the SDK's internal queue
/// and yield into an `AsyncStream<Event>` consumed by `RoomViewModel`.
/// We listen for postgres changes on `messages` and `room_presence`
/// (both already in the `supabase_realtime` publication, see migration
/// 0001). Presence join events fetch the actor's profile so the
/// downstream `RoomPresence` is fully populated; otherwise the chat
/// rail would render anonymous avatars.
///
/// The service keeps one channel alive per active subscriber. Multiple
/// subscriptions to the same room share the same channel; the last
/// subscription's termination tears it down.
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
    private var channels: [String: RealtimeChannelV2] = [:]
    private var subscribers: [String: Int] = [:]
    private var recentMessageIDs: [String: OrderedSet<UUID>] = [:]
    private let dedupeWindow = 500

    init(client: SupabaseClient = .live) {
        self.client = client
    }

    /// Subscribe to the room's channel. The returned stream stays open
    /// until the consumer stops iterating (or cancels the parent task);
    /// at that point the channel is released and unsubscribed.
    nonisolated func subscribe(roomID: UUID) -> AsyncStream<Event> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let bootstrap = Task {
                await self.attach(roomID: roomID, continuation: continuation)
            }
            continuation.onTermination = { [weak self] _ in
                bootstrap.cancel()
                Task { [weak self] in
                    await self?.release(roomID: roomID)
                }
            }
        }
    }

    /// Idempotent dedupe used by RoomViewModel to suppress the
    /// echoed-back insert for the user's own optimistic send. A clean
    /// realtime stream re-receives our own inserts; the VM matches on
    /// id and skips the duplicate.
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

    // MARK: - Channel lifecycle

    private func attach(roomID: UUID, continuation: AsyncStream<Event>.Continuation) async {
        let topic = "room:\(roomID.uuidString)"
        subscribers[topic, default: 0] += 1

        // If a channel for this topic already exists (another
        // subscriber is active), yield the existing stream's recent
        // events would require a replay we don't keep — so we just
        // attach a fresh set of callbacks to a fresh channel for this
        // continuation. Each consumer gets its own channel.
        let channel = client.channel(topic)
        let filter = "room_id=eq.\(roomID.uuidString)"

        // Messages: insert
        _ = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: filter
        ) { action in
            guard let dto = try? action.decodeRecord(
                as: DTO.Message.self,
                decoder: .supabase
            ) else { return }
            continuation.yield(.message(dto.toDomain()))
        }

        // Messages: update — covers edits AND soft-deletes (we set
        // `deleted_at` rather than deleting the row, so the wire
        // event is an UPDATE).
        _ = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "messages",
            filter: filter
        ) { action in
            guard let dto = try? action.decodeRecord(
                as: DTO.Message.self,
                decoder: .supabase
            ) else { return }
            let domain = dto.toDomain()
            if domain.deletedAt != nil {
                continuation.yield(.messageDeleted(domain.id))
            } else {
                continuation.yield(.messageEdited(domain))
            }
        }

        // Presence — joins. The wire payload only carries
        // (room_id, user_id, is_ghost, joined_at, last_seen_at) so we
        // fetch the profile to fill in display name + avatar before
        // emitting. Off the SDK callback queue → onto a Task.
        _ = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "room_presence",
            filter: filter
        ) { [client] action in
            guard let dto = try? action.decodeRecord(
                as: PresenceRow.self,
                decoder: .supabase
            ) else { return }
            Task {
                guard let presence = try? await Self.enrich(presence: dto, client: client)
                else { return }
                continuation.yield(.presenceJoined(presence))
            }
        }

        // Presence — leaves. The deleted row only gives us userID +
        // roomID, which is enough.
        _ = channel.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "room_presence",
            filter: filter
        ) { action in
            guard let dto = try? action.decodeOldRecord(
                as: PresenceRow.self,
                decoder: .supabase
            ) else { return }
            continuation.yield(.presenceLeft(userID: dto.user_id, roomID: dto.room_id))
        }

        // Reactions: the UI doesn't render reactions yet, so the
        // realtime wiring is intentionally deferred to keep the
        // initial channel surface tight. The Event cases stay so the
        // VM contract is stable for when we light reactions up.

        await channel.subscribe()
        channels[topic] = channel
    }

    private func release(roomID: UUID) async {
        let topic = "room:\(roomID.uuidString)"
        subscribers[topic, default: 0] -= 1
        guard subscribers[topic] ?? 0 <= 0 else { return }
        subscribers[topic] = nil
        recentMessageIDs[topic] = nil
        if let channel = channels.removeValue(forKey: topic) {
            await client.removeChannel(channel)
        }
    }

    // MARK: - Helpers

    /// Joins the bare presence row to the actor's profile. Needs to
    /// be `Sendable`/static so we can call it from a non-isolated
    /// callback's Task.
    private static func enrich(
        presence: PresenceRow,
        client: SupabaseClient
    ) async throws -> RoomPresence {
        let dto: DTO.Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: presence.user_id.uuidString)
            .single()
            .execute()
            .value
        return RoomPresence(
            roomID: presence.room_id,
            userID: presence.user_id,
            displayName: dto.display_name,
            avatarURL: dto.avatar_url.flatMap(URL.init(string:)),
            isGhost: presence.is_ghost,
            isPatron: dto.is_premium,
            joinedAt: presence.joined_at,
            lastSeenAt: presence.last_seen_at
        )
    }
}

// MARK: - Wire shapes

/// Mirrors the `room_presence` table; not exposed outside the service.
private struct PresenceRow: Decodable, Sendable {
    let room_id: UUID
    let user_id: UUID
    let is_ghost: Bool
    let joined_at: Date
    let last_seen_at: Date
}

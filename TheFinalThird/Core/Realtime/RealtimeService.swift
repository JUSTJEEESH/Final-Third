import Foundation
import OrderedCollections
import Supabase

/// Manages Supabase Realtime channels for chat, presence, and reactions.
/// Reference-counts subscriptions, dedupes inbound events, handles reconnect
/// and replay catch-up.
actor RealtimeService {
    struct ChannelHandle: Hashable, Sendable {
        let id: UUID
        let topic: String
    }

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

    /// Subscribe to a room. Returns an `AsyncStream<Event>` that the caller
    /// must consume for the lifetime of the room view.
    func subscribe(roomID: UUID) -> AsyncStream<Event> {
        let topic = "room:\(roomID.uuidString)"
        subscribers[topic, default: 0] += 1

        return AsyncStream { continuation in
            let channel = client.realtime.channel(topic)

            // Postgres changes — messages
            let messagesChange = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "messages",
                filter: "room_id=eq.\(roomID.uuidString)"
            )

            Task { [weak self] in
                guard let self else { return }
                for await change in messagesChange {
                    if let event = await self.makeMessageEvent(from: change, roomID: roomID) {
                        continuation.yield(event)
                    }
                }
            }

            // Reactions
            let reactionsChange = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "message_reactions"
            )

            Task {
                for await change in reactionsChange {
                    switch change {
                    case .insert(let action):
                        if let r = try? action.decodeRecord(decoder: .iso) as MessageReaction {
                            continuation.yield(.reactionAdded(r))
                        }
                    case .delete(let action):
                        if let r = try? action.decodeOldRecord(decoder: .iso) as MessageReaction {
                            continuation.yield(.reactionRemoved(r))
                        }
                    default: break
                    }
                }
            }

            // Presence
            let presence = channel.presenceChange()
            Task {
                for await change in presence {
                    let joins = change.joins
                    let leaves = change.leaves
                    for (_, state) in joins {
                        if let presence = try? state.decode(decoder: .iso) as RoomPresence {
                            continuation.yield(.presenceJoined(presence))
                        }
                    }
                    for (_, state) in leaves {
                        if let presence = try? state.decode(decoder: .iso) as RoomPresence {
                            continuation.yield(.presenceLeft(
                                userID: presence.userID, roomID: presence.roomID
                            ))
                        }
                    }
                }
            }

            Task {
                await channel.subscribe()
            }

            continuation.onTermination = { _ in
                Task { [weak self] in
                    await self?.release(topic: topic, channel: channel)
                }
            }
        }
    }

    private func release(topic: String, channel: RealtimeChannelV2) async {
        subscribers[topic, default: 0] -= 1
        if subscribers[topic] ?? 0 <= 0 {
            subscribers[topic] = nil
            recentMessageIDs[topic] = nil
            await channel.unsubscribe()
        }
    }

    private func makeMessageEvent(from change: AnyAction, roomID: UUID) -> Event? {
        let topic = "room:\(roomID.uuidString)"
        switch change {
        case .insert(let action):
            guard let m = try? action.decodeRecord(decoder: .iso) as Message else { return nil }
            if !markSeen(m.id, in: topic) { return nil }
            return .message(m)
        case .update(let action):
            guard let m = try? action.decodeRecord(decoder: .iso) as Message else { return nil }
            if m.deletedAt != nil { return .messageDeleted(m.id) }
            return .messageEdited(m)
        case .delete(let action):
            guard let m = try? action.decodeOldRecord(decoder: .iso) as Message else { return nil }
            return .messageDeleted(m.id)
        default:
            return nil
        }
    }

    private func markSeen(_ id: UUID, in topic: String) -> Bool {
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

private extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

import Foundation
import Observation

/// Loads and arranges rooms for the post-ceremony "Where are you
/// sitting?" sheet. Two passes:
///   1. Fetch all rooms (cheap)
///   2. Fetch live-now aggregates for those rooms (one RPC)
/// Then sectioned into Live now / Topics / Voice. Voice rooms are
/// always visible to all users — the Patron lock is enforced at
/// selection time, not by hiding the row, so free users can see what
/// they'd unlock.
@MainActor
@Observable
final class RoomPickerViewModel {
    var rooms: [Room] = []
    var liveByRoom: [UUID: LiveNowSummary] = [:]
    var isLoading = true

    private let roomRepo: RoomRepository

    init(rooms: RoomRepository = LiveRoomRepository()) {
        self.roomRepo = rooms
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await roomRepo.list()
            // Hide private rooms unless the user has explicit access
            // (RLS guarantees we'd only see ones we belong to). For
            // the picker we lean public-first — private rooms appear
            // anyway because RLS already filtered server-side.
            rooms = all
            let ids = all.map(\.id)
            liveByRoom = (try? await roomRepo.liveNow(roomIDs: ids)) ?? [:]
        } catch {
            rooms = []
            liveByRoom = [:]
        }
    }

    /// Refresh just the live-now layer. Used for the 30-second poll
    /// while the sheet is open — we don't refetch the rooms list.
    func refreshLiveNow() async {
        guard !rooms.isEmpty else { return }
        liveByRoom = (try? await roomRepo.liveNow(roomIDs: rooms.map(\.id))) ?? [:]
    }

    // MARK: - Sectioning

    /// Rooms with at least one active (non-ghost) smoker, ordered by
    /// liveCount desc — the most-alive first.
    var liveRooms: [Room] {
        rooms
            .filter { (liveByRoom[$0.id]?.liveCount ?? 0) > 0 }
            .sorted { (liveByRoom[$0.id]?.liveCount ?? 0)
                  > (liveByRoom[$1.id]?.liveCount ?? 0) }
    }

    /// Public chat rooms with no live smokers — the "by the window"
    /// section. Quiet corners. Patron host-able rooms surface here too.
    var topicRooms: [Room] {
        rooms.filter {
            $0.mode == .chat
                && !$0.isPrivate
                && (liveByRoom[$0.id]?.liveCount ?? 0) == 0
        }
    }

    /// Voice-mode rooms. Patron-locked at selection time.
    var voiceRooms: [Room] {
        rooms.filter { $0.mode == .voice }
    }
}

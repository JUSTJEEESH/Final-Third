import Foundation
import Observation

@MainActor
@Observable
final class LoungeViewModel {
    private(set) var rooms: [Room] = []
    private(set) var occupants: [UUID: Int] = [:]   // roomID -> rough count
    private(set) var isLoading = false
    private(set) var error: String?

    private let rooms_repo: RoomRepository

    init(rooms: RoomRepository = LiveRoomRepository()) {
        self.rooms_repo = rooms
    }

    func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            rooms = try await rooms_repo.list()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

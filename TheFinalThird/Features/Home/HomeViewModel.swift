import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    var profile: Profile?
    var usual: Usual?
    var usualCigar: Cigar?
    var tonightsPick: Cigar?
    var activeRooms: [Room] = []
    var currentDrop: CigarDrop?
    var dropCigar: Cigar?
    var nearbyEvents: [LoungeEvent] = []
    var isLoading = false

    private let userID: UUID
    private let profiles: ProfileRepository
    private let usuals: UsualRepository
    private let cigars: CigarRepository
    private let rooms: RoomRepository
    private let drops: DropRepository
    private let events: EventRepository
    private let config: ConfigService

    init(
        userID: UUID,
        profiles: ProfileRepository = LiveProfileRepository(),
        usuals: UsualRepository = LiveUsualRepository(),
        cigars: CigarRepository = LiveCigarRepository(),
        rooms: RoomRepository = LiveRoomRepository(),
        drops: DropRepository = LiveDropRepository(),
        events: EventRepository = LiveEventRepository(),
        config: ConfigService
    ) {
        self.userID = userID
        self.profiles = profiles
        self.usuals = usuals
        self.cigars = cigars
        self.rooms = rooms
        self.drops = drops
        self.events = events
        self.config = config
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let key: String
        switch hour {
        case 0..<6: key = "greeting.late"
        case 6..<17: key = "greeting.morning"
        default: key = "greeting.evening"
        }
        return config.string(key) ?? "Welcome back."
    }

    func load() async {
        isLoading = true; defer { isLoading = false }
        await config.refreshIfStale()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [self] in profile = (try? await profiles.fetch(id: userID)) }
            group.addTask { [self] in
                let u = (try? await usuals.fetch(userID: userID))
                self.usual = u
                if let cigarID = u?.cigarID {
                    self.usualCigar = try? await cigars.fetch(id: cigarID)
                }
            }
            group.addTask { [self] in
                let all = (try? await rooms.list()) ?? []
                self.activeRooms = Array(all.prefix(4))
            }
            group.addTask { [self] in
                let drop = try? await drops.current()
                self.currentDrop = drop
                if let cigarID = drop?.cigarID {
                    self.dropCigar = try? await cigars.fetch(id: cigarID)
                }
            }
            group.addTask { [self] in
                let city = (try? await profiles.fetch(id: userID))?.city
                self.nearbyEvents = (try? await events.upcoming(city: city, limit: 3)) ?? []
            }
        }
        // Tonight's pick: usual cigar, else dropCigar, else first listed.
        tonightsPick = usualCigar ?? dropCigar
    }
}

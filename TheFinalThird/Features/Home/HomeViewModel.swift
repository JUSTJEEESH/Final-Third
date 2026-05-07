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
    /// First upcoming drop after `currentDrop` ends (or first drop in
    /// the future when no drop is live). Drives the teaser card on Home.
    var upcomingDrop: CigarDrop?
    var upcomingDropCigar: Cigar?
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

        async let profileTask = profiles.fetch(id: userID)
        async let usualTask = usuals.fetch(userID: userID)
        async let roomsTask = rooms.list()
        async let dropTask = drops.current()
        async let upcomingDropsTask = drops.upcoming(limit: 1)

        profile = try? await profileTask
        let usual = try? await usualTask
        self.usual = usual
        if let cigarID = usual?.cigarID {
            usualCigar = try? await cigars.fetch(id: cigarID)
        }

        let allRooms = (try? await roomsTask) ?? []
        activeRooms = Array(allRooms.prefix(4))

        let drop = try? await dropTask
        currentDrop = drop
        if let cigarID = drop?.cigarID {
            dropCigar = try? await cigars.fetch(id: cigarID)
        }

        let upcoming = (try? await upcomingDropsTask) ?? []
        upcomingDrop = upcoming.first
        if let cigarID = upcoming.first?.cigarID {
            upcomingDropCigar = try? await cigars.fetch(id: cigarID)
        }

        let city = profile?.city
        nearbyEvents = (try? await events.upcoming(city: city, limit: 3)) ?? []

        tonightsPick = usualCigar ?? dropCigar
    }
}

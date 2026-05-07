import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    enum TonightsPickSource: Sendable, Equatable {
        case liveDrop
        case upcomingDrop(daysAway: Int)
        case dailyFeatured
    }

    var profile: Profile?
    var usual: Usual?
    var usualCigar: Cigar?
    var usualDrink: Drink?
    /// The cigar shown in Tonight's Pick. Never the user's Usual —
    /// that's Your Ritual's job. Falls through live drop → upcoming
    /// drop → daily-rotating featured cigar from the catalog.
    var tonightsPick: Cigar?
    var tonightsPickSource: TonightsPickSource?
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
    private let drinks: DrinkRepository
    private let rooms: RoomRepository
    private let drops: DropRepository
    private let events: EventRepository
    private let config: ConfigService

    init(
        userID: UUID,
        profiles: ProfileRepository = LiveProfileRepository(),
        usuals: UsualRepository = LiveUsualRepository(),
        cigars: CigarRepository = LiveCigarRepository(),
        drinks: DrinkRepository = LiveDrinkRepository(),
        rooms: RoomRepository = LiveRoomRepository(),
        drops: DropRepository = LiveDropRepository(),
        events: EventRepository = LiveEventRepository(),
        config: ConfigService
    ) {
        self.userID = userID
        self.profiles = profiles
        self.usuals = usuals
        self.cigars = cigars
        self.drinks = drinks
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
        if let drinkID = usual?.drinkID {
            usualDrink = try? await drinks.fetch(id: drinkID)
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

        // Tonight's Pick is a *suggestion* — never the user's Usual
        // (that lives in Your Ritual). Live drop > upcoming drop >
        // daily-rotating featured cigar from the catalog so the slot
        // always has fresh editorial content.
        if let dropCigar {
            tonightsPick = dropCigar
            tonightsPickSource = .liveDrop
        } else if let upcomingDropCigar, let upcoming = upcomingDrop {
            tonightsPick = upcomingDropCigar
            let days = Calendar.current.dateComponents(
                [.day], from: .now, to: upcoming.startsAt
            ).day ?? 0
            tonightsPickSource = .upcomingDrop(daysAway: max(days, 0))
        } else {
            // Daily featured — deterministic per calendar day.
            tonightsPick = try? await cigars.featured(forDay: .now)
            if tonightsPick != nil { tonightsPickSource = .dailyFeatured }
        }
    }
}

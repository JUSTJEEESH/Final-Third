import Foundation

@MainActor
@Observable
final class OnboardingViewModel {
    /// Linear flow. Welcome + intro feel like teaser screens; the
    /// `setupIndex` getter drives the progress dots so users see
    /// "1 of 7" only during the actual setup phase.
    enum Step: Int, CaseIterable, Sendable {
        case welcome = 0
        case intro
        case name
        case avatar
        case location
        case usual
        case vibe
        case notifications
        case ready

        /// Position in the setup pipeline (0-indexed). Welcome and
        /// intro return nil so they don't show progress.
        var setupIndex: Int? {
            switch self {
            case .welcome, .intro: return nil
            case .name: return 0
            case .avatar: return 1
            case .location: return 2
            case .usual: return 3
            case .vibe: return 4
            case .notifications: return 5
            case .ready: return 6
            }
        }

        static var setupCount: Int { 7 }
    }

    var step: Step = .welcome
    var introIndex: Int = 0
    let introCount: Int = 3
    var error: String?
    var isSaving = false

    // Step: name
    var displayName: String = ""
    var handle: String = ""
    var bio: String = ""

    // Step: avatar
    var avatarURL: URL?

    // Step: location
    var city: String = ""
    var isHondurasLocal: Bool = false
    let timezone: String = TimeZone.current.identifier

    // Step: the usual
    var preferredTime: Date = {
        Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now) ?? .now
    }()
    var cigar: Cigar?
    var drink: Drink?
    var cigars: [Cigar] = []
    var drinks: [Drink] = []
    var enableUsualReminder: Bool = true

    // Step: vibe
    var audioTheme: AudioTheme = .loungeMurmur
    var ghostModeDefault: Bool = false
    var voiceEnabled: Bool = false

    // Step: notifications — opt-in tracked here so the recap shows it
    // and the "Take my chair" save can schedule the local reminder.
    var didRequestNotifications: Bool = false
    var notificationsGranted: Bool = false

    // MARK: Dependencies

    let userID: UUID
    private let profiles: ProfileRepository
    private let usuals: UsualRepository
    private let cigarsRepo: CigarRepository
    private let drinksRepo: DrinkRepository
    private let notifications: NotificationService
    private let onComplete: () -> Void

    init(
        userID: UUID,
        emailFromSession _: String?,
        presetDisplayName: String?,
        profiles: ProfileRepository = LiveProfileRepository(),
        usuals: UsualRepository = LiveUsualRepository(),
        cigars: CigarRepository = LiveCigarRepository(),
        drinks: DrinkRepository = LiveDrinkRepository(),
        notifications: NotificationService,
        onComplete: @escaping () -> Void
    ) {
        self.userID = userID
        self.profiles = profiles
        self.usuals = usuals
        self.cigarsRepo = cigars
        self.drinksRepo = drinks
        self.notifications = notifications
        self.onComplete = onComplete
        if let presetDisplayName, !presetDisplayName.isEmpty {
            self.displayName = presetDisplayName
        }
    }

    // MARK: Lifecycle

    func loadCatalog() async {
        async let cigarsTask = (try? await cigarsRepo.search(.init(), limit: 200)) ?? []
        async let drinksTask = (try? await drinksRepo.list(category: nil)) ?? []
        cigars = await cigarsTask
        drinks = await drinksTask
    }

    // MARK: Navigation

    var canContinue: Bool {
        switch step {
        case .name: return !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    var canGoBack: Bool { step.rawValue > 0 }

    func next() {
        guard canContinue else { return }
        // On the intro step, advance the carousel before moving to the
        // next outer step.
        if step == .intro && introIndex < introCount - 1 {
            HapticsService.shared.soft()
            introIndex += 1
            return
        }
        if let nextStep = Step(rawValue: step.rawValue + 1) {
            HapticsService.shared.tap()
            step = nextStep
        }
    }

    func back() {
        if step == .intro && introIndex > 0 {
            HapticsService.shared.soft()
            introIndex -= 1
            return
        }
        if let prev = Step(rawValue: step.rawValue - 1) {
            HapticsService.shared.tap()
            step = prev
        }
    }

    // MARK: Notifications

    func requestNotificationPermission() async {
        await notifications.requestAuthorization()
        await notifications.bootstrap()
        didRequestNotifications = true
        notificationsGranted = notifications.authorization == .authorized
            || notifications.authorization == .provisional
    }

    // MARK: Save

    func save() async -> Bool {
        error = nil; isSaving = true; defer { isSaving = false }

        let profile = Profile(
            id: userID,
            email: nil,
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            handle: handle.trimmingCharacters(in: .whitespaces).isEmpty ? nil : handle,
            avatarURL: avatarURL,
            bio: bio.isEmpty ? nil : bio,
            city: city.isEmpty ? nil : city,
            isHondurasLocal: isHondurasLocal,
            isPremium: false,
            audioTheme: audioTheme,
            voiceEnabled: voiceEnabled,
            ghostModeDefault: ghostModeDefault,
            notificationPrefs: .default,
            quietHoursStart: nil,
            quietHoursEnd: nil,
            timezone: timezone,
            createdAt: .now
        )

        let comps = Calendar.current.dateComponents([.hour, .minute], from: preferredTime)
        let tod = TimeOfDay(hour: comps.hour ?? 21, minute: comps.minute ?? 0)

        do {
            try await profiles.upsert(profile)
            try await usuals.upsert(
                userID: userID,
                time: tod,
                cigarID: cigar?.id,
                drinkID: drink?.id,
                enabled: enableUsualReminder
            )
            // Only schedule the local reminder if the user actually
            // granted notifications during the notifications step. If
            // they declined or skipped, don't queue something they
            // won't see.
            if enableUsualReminder && notificationsGranted {
                await notifications.scheduleUsual(at: tod)
            } else if !enableUsualReminder {
                notifications.cancelUsual()
            }
            HapticsService.shared.success()
            onComplete()
            return true
        } catch {
            self.error = "Couldn't save your profile: \(error.localizedDescription)"
            return false
        }
    }
}

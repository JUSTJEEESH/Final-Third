import Foundation

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case name = 0
        case location
        case usual
        case vibe
        case ready
    }

    var step: Step = .name
    var error: String?
    var isSaving = false

    // Step 1 — name
    var displayName: String = ""
    var handle: String = ""
    var bio: String = ""

    // Step 2 — location
    var city: String = ""
    var isHondurasLocal: Bool = false
    let timezone: String = TimeZone.current.identifier

    // Step 3 — the usual
    var preferredTime: Date = {
        Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now) ?? .now
    }()
    var cigar: Cigar?
    var drink: Drink?
    var cigars: [Cigar] = []
    var drinks: [Drink] = []
    var enableUsualReminder: Bool = true

    // Step 4 — vibe + privacy
    var audioTheme: AudioTheme = .loungeMurmur
    var ghostModeDefault: Bool = false
    var voiceEnabled: Bool = false

    // MARK: Dependencies

    private let userID: UUID
    private let profiles: ProfileRepository
    private let usuals: UsualRepository
    private let cigarsRepo: CigarRepository
    private let drinksRepo: DrinkRepository
    private let notifications: NotificationService
    private let onComplete: () -> Void

    init(
        userID: UUID,
        emailFromSession: String?,
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
        case .name:
            return !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        default:
            return true
        }
    }

    var canGoBack: Bool {
        step.rawValue > 0
    }

    func next() {
        guard canContinue else { return }
        if let nextStep = Step(rawValue: step.rawValue + 1) {
            HapticsService.shared.tap()
            step = nextStep
        }
    }

    func back() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            HapticsService.shared.tap()
            step = prev
        }
    }

    // MARK: Save

    func save() async -> Bool {
        error = nil; isSaving = true; defer { isSaving = false }

        let profile = Profile(
            id: userID,
            email: nil,
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            handle: handle.trimmingCharacters(in: .whitespaces).isEmpty ? nil : handle,
            avatarURL: nil,
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
            if enableUsualReminder {
                await notifications.scheduleUsual(at: tod)
            } else {
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

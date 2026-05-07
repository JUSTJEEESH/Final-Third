import Foundation
import SwiftUI

/// Lightweight DI container. Lives for the app's lifetime; passed via
/// `@Environment(AppContainer.self)`. ViewModels read what they need in init.
@MainActor
@Observable
final class AppContainer {
    let auth: AuthService
    let config: ConfigService
    let entitlements: EntitlementService
    let notifications: NotificationService
    let realtime: RealtimeService
    let voice: VoiceService
    let audio: AudioEngine
    let offlineQueue: OfflineQueue
    let analytics: AnalyticsService

    /// Active session state — global so views outside the session flow
    /// (Lounge, Room, Home, the persistent session bar) can read what's
    /// burning right now. Owned here, mutated by SessionFlowView and the
    /// "Light up here" CTAs in rooms.
    let session: SessionState

    /// Routing flag: when signed in but no `profiles` row exists, the user
    /// has to complete onboarding before reaching the main tab bar.
    var needsOnboarding: Bool = false

    private let profiles: ProfileRepository

    init(profiles: ProfileRepository = LiveProfileRepository()) {
        self.auth = AuthService()
        self.config = ConfigService()
        self.entitlements = EntitlementService()
        self.notifications = NotificationService()
        self.realtime = RealtimeService()
        self.voice = VoiceService()
        self.audio = AudioEngine()
        self.offlineQueue = OfflineQueue()
        self.analytics = AnalyticsService()
        self.session = SessionState()
        self.profiles = profiles
    }

    func bootstrap() async {
        await auth.bootstrap()
        await notifications.bootstrap()
        await config.refreshIfStale()
        if case .signedIn(let userID) = auth.state {
            entitlements.bootstrap(appUserID: userID.uuidString)
            await checkOnboarding(userID: userID)
        }
    }

    /// Checks if a `profiles` row exists for the signed-in user. If not, the
    /// session is "orphaned" (auth user without a profile) and we route to
    /// onboarding. If the auth.users row was deleted server-side but a stale
    /// token persists in the keychain, the fetch returns a 401-ish error;
    /// we treat that as needing onboarding too — completion will fail and
    /// the user can sign out from there.
    func checkOnboarding(userID: UUID) async {
        do {
            _ = try await profiles.fetch(id: userID)
            needsOnboarding = false
        } catch {
            needsOnboarding = true
        }
    }

    /// Called by the onboarding flow when it finishes successfully.
    func markOnboardingComplete() {
        needsOnboarding = false
    }
}

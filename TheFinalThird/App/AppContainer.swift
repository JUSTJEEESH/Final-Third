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

    init() {
        self.auth = AuthService()
        self.config = ConfigService()
        self.entitlements = EntitlementService()
        self.notifications = NotificationService()
        self.realtime = RealtimeService()
        self.voice = VoiceService()
        self.audio = AudioEngine()
        self.offlineQueue = OfflineQueue()
        self.analytics = AnalyticsService()
    }

    func bootstrap() async {
        await auth.bootstrap()
        await notifications.bootstrap()
        await config.refreshIfStale()
        if case .signedIn(let userID) = auth.state {
            entitlements.bootstrap(appUserID: userID.uuidString)
        }
    }
}

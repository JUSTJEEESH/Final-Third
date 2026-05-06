import UIKit

/// Minimal AppDelegate used solely for APNs registration. SwiftUI scene
/// lifecycle handles everything else.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool { true }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            // Container is read on first scene; the token is stored statically
            // and consumed by NotificationService once it's available.
            PendingPushToken.data = deviceToken
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Non-fatal; user can retry from Settings.
    }
}

@MainActor
enum PendingPushToken {
    static var data: Data?
}

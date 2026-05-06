import Foundation
import UIKit
import UserNotifications

/// Handles APNs registration, local notifications for The Usual, and
/// quiet-hours suppression.
@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private(set) var deviceToken: String?

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func bootstrap() async {
        let settings = await center.notificationSettings()
        authorization = settings.authorizationStatus
    }

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await bootstrap()
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
        } catch {
            // ignore — user can re-trigger from Settings.
        }
    }

    /// Register the APNs device token. Called from AppDelegate hook.
    func registerToken(_ data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: The Usual local notification

    func scheduleUsual(at time: TimeOfDay, identifier: String = "the_usual") async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Your chair is ready."
        content.sound = nil
        content.interruptionLevel = .passive

        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelUsual(identifier: String = "the_usual") {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}

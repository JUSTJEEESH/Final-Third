import Foundation
import OSLog

/// Typed analytics. No free-text properties; events are an enum so we can
/// audit at compile time. Backend is pluggable; default is OSLog.
@MainActor
final class AnalyticsService {
    enum Event: Sendable {
        case appOpened
        case signedIn
        case sessionStarted(cigarID: UUID?, drinkID: UUID?)
        case sessionEnded(duration: Int, rated: Bool)
        case lightingCeremonyShown(method: Session.LightingMethod)
        case lightingCeremonyCompleted
        case roomJoined(roomID: UUID, ghost: Bool)
        case roomLeft(roomID: UUID)
        case messageSent(roomID: UUID)
        case voiceTransmitted(roomID: UUID, durationMs: Int)
        case finalThirdMoment(roomID: UUID?)
        case paywallShown(trigger: String)
        case paywallPurchased(productID: String)
    }

    private let logger = Logger(subsystem: "com.thefinalthird.app", category: "analytics")

    func track(_ event: Event) {
        logger.info("\(String(describing: event), privacy: .public)")
    }
}

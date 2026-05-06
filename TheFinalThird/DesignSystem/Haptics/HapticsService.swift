import CoreHaptics
import UIKit

/// Centralized haptics. All call sites go through this — keeps patterns
/// consistent and lets us no-op on devices without CHHapticEngine support.
@MainActor
final class HapticsService {
    static let shared = HapticsService()

    private var engine: CHHapticEngine?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    // MARK: Simple feedback (uses UIKit generators — already low-overhead)

    func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
    }

    func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
    }

    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    // MARK: Ritual patterns

    /// Lighting ceremony: ignition tick → low rumble → settle pulse.
    func playLightingPattern() {
        guard let engine else { tap(); return }
        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [.init(parameterID: .hapticIntensity, value: 0.9),
                                 .init(parameterID: .hapticSharpness, value: 0.85)],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [.init(parameterID: .hapticIntensity, value: 0.55),
                                 .init(parameterID: .hapticSharpness, value: 0.15)],
                    relativeTime: 0.5,
                    duration: 1.4
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [.init(parameterID: .hapticIntensity, value: 0.7),
                                 .init(parameterID: .hapticSharpness, value: 0.4)],
                    relativeTime: 4.0
                ),
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            tap()
        }
    }

    /// Final third moment: triple-pulse at low frequency, mirroring the gold pulse.
    func playFinalThirdPattern() {
        guard let engine else { success(); return }
        do {
            let events = (0 ..< 3).map { i in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [.init(parameterID: .hapticIntensity, value: 0.6),
                                 .init(parameterID: .hapticSharpness, value: 0.3)],
                    relativeTime: TimeInterval(i) * 0.4
                )
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            success()
        }
    }

    /// Arrival signal: one soft pulse — never aggressive.
    func playArrivalSignal() {
        soft()
    }
}

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

    /// Generic lighting pattern (kept for non-method-aware callers).
    /// Prefer `playLightingPattern(for:)`.
    func playLightingPattern() {
        playLightingPattern(for: .softFlame)
    }

    /// Per-method lighting haptic — different physical feel for each method.
    /// match: crisp scratch → soft rumble → settle.
    /// torch: sharp click → tight high-frequency jet → tap.
    /// cedar: soft tap → long warm low rumble → settle.
    /// softFlame: spring click → medium rumble → settle.
    func playLightingPattern(for method: Session.LightingMethod) {
        guard let engine else { tap(); return }
        do {
            let events: [CHHapticEvent]
            switch method {
            case .match:
                events = [
                    transient(at: 0,    intensity: 0.95, sharpness: 0.95),
                    continuous(at: 0.45, duration: 1.4, intensity: 0.55, sharpness: 0.20),
                    transient(at: 4.0,  intensity: 0.65, sharpness: 0.40),
                ]
            case .torch:
                events = [
                    transient(at: 0,     intensity: 1.0,  sharpness: 1.0),
                    continuous(at: 0.05, duration: 0.7, intensity: 0.85, sharpness: 0.85),
                    transient(at: 1.0,   intensity: 0.55, sharpness: 0.65),
                ]
            case .cedar:
                events = [
                    transient(at: 0,     intensity: 0.55, sharpness: 0.30),
                    continuous(at: 0.30, duration: 2.6, intensity: 0.50, sharpness: 0.10),
                    transient(at: 4.5,   intensity: 0.70, sharpness: 0.30),
                ]
            case .softFlame:
                events = [
                    transient(at: 0,     intensity: 0.85, sharpness: 0.75),
                    continuous(at: 0.18, duration: 1.2, intensity: 0.55, sharpness: 0.25),
                    transient(at: 3.5,   intensity: 0.65, sharpness: 0.35),
                ]
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            tap()
        }
    }

    private func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private func continuous(at time: TimeInterval, duration: TimeInterval,
                            intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time,
            duration: duration
        )
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

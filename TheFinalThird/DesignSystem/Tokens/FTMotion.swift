import SwiftUI

/// Motion tokens. Curves are tuned for warmth — never bouncy.
enum FTMotion {
    // Durations
    static let quick:   Duration = .milliseconds(180)
    static let smooth:  Duration = .milliseconds(320)
    static let slow:    Duration = .milliseconds(520)
    static let breathe: Duration = .milliseconds(800)
    static let ritual:  Duration = .milliseconds(1600)

    // SwiftUI Animation values
    static let easeOutSoft = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.32)
    static let easeInOutSoft = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.32)
    static let breatheCurve = Animation.timingCurve(0.45, 0.05, 0.55, 0.95, duration: 0.8)
        .repeatForever(autoreverses: true)
    static let goldPulse = Animation.timingCurve(0.42, 0.0, 0.58, 1.0, duration: 1.6)
        .repeatForever(autoreverses: true)
}

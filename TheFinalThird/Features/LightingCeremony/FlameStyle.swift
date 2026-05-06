import SwiftUI

/// Per-lighting-method physical character of the flame. Drives the canvas
/// renderer (color, shape, flicker), the choreography timing, the smoke
/// intensity, and the haptic pattern. Tuning these tokens is how the
/// ceremony feels different for a match vs. a torch vs. cedar.
struct FlameStyle: Sendable {
    // MARK: Color
    let coreColor: Color       // white-hot inner sliver
    let bodyColor: Color       // main flame body
    let outerColor: Color      // fading edge / halo
    let haloColor: Color       // ground glow at the base

    // MARK: Shape (relative to canvas size)
    let baseWidth: CGFloat       // 0…1 of canvas width
    let height: CGFloat          // 0…1 of canvas height
    let lobeCount: Int           // number of overlapping flame "tongues"

    // MARK: Behaviour
    let flickerRate: Double      // Hz
    let flickerAmount: Double    // 0…1, how much the silhouette wobbles
    let breathRate: Double       // slow size pulse (for relaxation cadence)
    let sparkRate: Double        // sparks per second (rough)
    let smokeIntensity: Double   // 0…1, drives smoke opacity + count

    // MARK: Choreography
    let ignitionDuration: TimeInterval   // how long the flame takes to fully ignite
    let revealAt: TimeInterval           // when cigar name fades in
    let promptAt: TimeInterval           // when "tap to take your seat" appears
    let totalDuration: TimeInterval      // total ceremony length

    // MARK: Copy
    let toolSymbol: String
    let toolName: String
    let methodCopy: String       // a sentence shown during ignition

    static func forMethod(_ method: Session.LightingMethod) -> FlameStyle {
        switch method {
        case .match: return .match
        case .torch: return .torch
        case .cedar: return .cedar
        case .softFlame: return .softFlame
        }
    }

    // MARK: Presets

    static let match = FlameStyle(
        coreColor: Color(hex: 0xFFF7D8),
        bodyColor: Color(hex: 0xFFB347),
        outerColor: Color(hex: 0xFF6A1A),
        haloColor: Color(hex: 0xFF8030).opacity(0.55),
        baseWidth: 0.18, height: 0.55, lobeCount: 4,
        flickerRate: 8.0, flickerAmount: 0.55, breathRate: 0.6,
        sparkRate: 14, smokeIntensity: 0.35,
        ignitionDuration: 1.6, revealAt: 3.4, promptAt: 5.5, totalDuration: 6.4,
        toolSymbol: "fireworks", toolName: "Match",
        methodCopy: "A small, honest flame."
    )

    static let torch = FlameStyle(
        coreColor: Color(hex: 0xE8FBFF),
        bodyColor: Color(hex: 0x9CC9FF),
        outerColor: Color(hex: 0x4775B5),
        haloColor: Color(hex: 0x2B5BAA).opacity(0.45),
        baseWidth: 0.10, height: 0.62, lobeCount: 2,
        flickerRate: 22.0, flickerAmount: 0.06, breathRate: 0.0,
        sparkRate: 0, smokeIntensity: 0.0,
        ignitionDuration: 0.7, revealAt: 2.2, promptAt: 4.4, totalDuration: 5.0,
        toolSymbol: "flame.fill", toolName: "Torch",
        methodCopy: "Direct. Efficient. Done."
    )

    static let cedar = FlameStyle(
        coreColor: Color(hex: 0xFFE8B0),
        bodyColor: Color(hex: 0xFFA45A),
        outerColor: Color(hex: 0xC04A1E),
        haloColor: Color(hex: 0xC95B25).opacity(0.65),
        baseWidth: 0.26, height: 0.50, lobeCount: 5,
        flickerRate: 4.5, flickerAmount: 0.40, breathRate: 0.45,
        sparkRate: 22, smokeIntensity: 0.65,
        ignitionDuration: 2.6, revealAt: 4.2, promptAt: 6.8, totalDuration: 7.6,
        toolSymbol: "leaf.fill", toolName: "Cedar Spill",
        methodCopy: "Slow. Worth the wait."
    )

    static let softFlame = FlameStyle(
        coreColor: Color(hex: 0xFFEBC0),
        bodyColor: Color(hex: 0xFFC868),
        outerColor: Color(hex: 0xE07628),
        haloColor: Color(hex: 0xE07628).opacity(0.45),
        baseWidth: 0.16, height: 0.52, lobeCount: 3,
        flickerRate: 6.5, flickerAmount: 0.32, breathRate: 0.55,
        sparkRate: 6, smokeIntensity: 0.20,
        ignitionDuration: 1.2, revealAt: 3.0, promptAt: 5.0, totalDuration: 5.8,
        toolSymbol: "flame", toolName: "Soft Flame",
        methodCopy: "The classic chair."
    )
}

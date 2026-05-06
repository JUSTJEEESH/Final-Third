import SwiftUI

/// Procedural flame rendered with `Canvas` + `TimelineView`. Cheap on all
/// devices and correct under Reduce Motion (caller swaps in a static frame).
/// Layered: ember halo (radial gradient), flame body (vertically warped
/// gradient with noise lobes), bright core, and rising sparks.
struct FlameCanvas: View {
    /// 0…1 — overall intensity. Drives size, brightness, and spark count.
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                draw(context: &context, size: size, time: t)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(context: inout GraphicsContext, size: CGSize, time t: TimeInterval) {
        let cx = size.width / 2
        let baseY = size.height * 0.78
        let scale = min(size.width, size.height) * intensity

        // 1) ember halo — large soft radial behind everything
        let haloRadius = scale * 0.7
        let haloGradient = Gradient(stops: [
            .init(color: FTColor.gold.opacity(0.0), location: 0.95),
            .init(color: FTColor.gold.opacity(0.15 * intensity), location: 0.6),
            .init(color: FTColor.ember.opacity(0.45 * intensity), location: 0.3),
            .init(color: FTColor.emberHot.opacity(0.6 * intensity), location: 0.05),
        ])
        let halo = Path(ellipseIn: CGRect(x: cx - haloRadius, y: baseY - haloRadius,
                                          width: haloRadius * 2, height: haloRadius * 2))
        context.fill(halo, with: .radialGradient(
            haloGradient,
            center: CGPoint(x: cx, y: baseY),
            startRadius: 0, endRadius: haloRadius
        ))

        // 2) flame body — three sinusoidal lobes ramped upward
        let lobeCount = 3
        let flameHeight = scale * 0.55
        for i in 0 ..< lobeCount {
            let phase = t * (1.4 + Double(i) * 0.35)
            let xJitter = sin(phase + Double(i)) * (scale * 0.04)
            let widthJitter = (sin(phase * 1.3 + Double(i) * 0.7) + 1) * 0.5
            let baseW = scale * (0.18 + 0.08 * widthJitter)

            var path = Path()
            path.move(to: CGPoint(x: cx - baseW / 2 + xJitter, y: baseY))
            path.addQuadCurve(
                to: CGPoint(x: cx + baseW / 2 + xJitter, y: baseY),
                control: CGPoint(x: cx + xJitter * 1.4,
                                 y: baseY - flameHeight - sin(phase) * scale * 0.04)
            )

            let stops: [Gradient.Stop] = [
                .init(color: FTColor.emberCore.opacity(0.95), location: 0.0),
                .init(color: FTColor.emberHot.opacity(0.85), location: 0.45),
                .init(color: FTColor.ember.opacity(0.55), location: 0.85),
                .init(color: FTColor.ember.opacity(0.0), location: 1.0),
            ]
            context.fill(path, with: .linearGradient(
                Gradient(stops: stops),
                startPoint: CGPoint(x: cx, y: baseY),
                endPoint: CGPoint(x: cx, y: baseY - flameHeight)
            ))
        }

        // 3) bright core — small inner blue/white sliver
        let corePhase = sin(t * 6) * 0.5 + 0.5
        let coreH = scale * 0.18 * (0.85 + 0.15 * corePhase)
        let coreW = scale * 0.05 * (0.85 + 0.15 * corePhase)
        var corePath = Path()
        corePath.move(to: CGPoint(x: cx - coreW / 2, y: baseY))
        corePath.addQuadCurve(to: CGPoint(x: cx + coreW / 2, y: baseY),
                              control: CGPoint(x: cx, y: baseY - coreH))
        context.fill(corePath, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.8), FTColor.emberCore.opacity(0.0)]),
            startPoint: CGPoint(x: cx, y: baseY),
            endPoint: CGPoint(x: cx, y: baseY - coreH)
        ))

        // 4) rising sparks — deterministic per-frame pseudo-random pattern
        let sparks = Int(20 * intensity)
        for i in 0 ..< sparks {
            let seed = Double(i) * 12.987
            let life = (t * 0.6 + seed).truncatingRemainder(dividingBy: 1.0)
            let opacity = max(0.0, 0.6 - life * 0.6) * intensity
            let xOffset = sin(seed * 6.28 + t) * scale * 0.18
            let yOffset = -life * scale * 0.7
            let radius = scale * 0.005 * (1.0 - life)

            let dot = Path(ellipseIn: CGRect(
                x: cx + xOffset - radius,
                y: baseY + yOffset - radius,
                width: radius * 2, height: radius * 2
            ))
            context.fill(dot, with: .color(FTColor.emberHot.opacity(opacity)))
        }
    }
}

import SwiftUI

/// Procedural flame rendered with `Canvas` + `TimelineView`. Method-aware
/// via `FlameStyle` — different lighting tools produce visibly different
/// flames (color, width, flicker, smoke).
///
/// Layered (back to front):
///   1. Halo — soft radial glow at the base
///   2. Smoke — drifting grey particles above the flame (off for torch)
///   3. Outer flame — wide turbulent body
///   4. Body flame — saturated middle gradient
///   5. Core flame — bright inner sliver
///   6. Sparks — rising specks
struct FlameCanvas: View {
    let style: FlameStyle
    /// 0…1, controls overall ignition state (0 = no flame, 1 = fully lit).
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                draw(into: &context,
                     size: size,
                     time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Render

    private func draw(into context: inout GraphicsContext, size: CGSize, time t: TimeInterval) {
        let cx = size.width / 2
        let baseY = size.height * 0.78
        let scale = min(size.width, size.height)

        // Slow breath envelope (relaxation cadence) — modulates intensity ±10%.
        let breath = style.breathRate > 0 ? (sin(t * style.breathRate) * 0.08) : 0
        let liveIntensity = max(0, min(intensity * (1 + breath), 1))
        guard liveIntensity > 0.01 else { return }

        drawHalo(into: &context, cx: cx, baseY: baseY, scale: scale, intensity: liveIntensity)
        if style.smokeIntensity > 0.01 {
            drawSmoke(into: &context, cx: cx, baseY: baseY, scale: scale,
                      time: t, intensity: liveIntensity)
        }
        drawFlameBody(into: &context, cx: cx, baseY: baseY, scale: scale,
                      time: t, intensity: liveIntensity)
        drawCore(into: &context, cx: cx, baseY: baseY, scale: scale,
                 time: t, intensity: liveIntensity)
        if style.sparkRate > 0.01 {
            drawSparks(into: &context, cx: cx, baseY: baseY, scale: scale,
                       time: t, intensity: liveIntensity)
        }
    }

    // 1. Halo — soft ground glow
    private func drawHalo(
        into context: inout GraphicsContext,
        cx: CGFloat, baseY: CGFloat, scale: CGFloat, intensity: Double
    ) {
        let r = scale * 0.55 * intensity
        let path = Path(ellipseIn: CGRect(
            x: cx - r, y: baseY - r * 0.65,
            width: r * 2, height: r * 1.3
        ))
        context.fill(path, with: .radialGradient(
            Gradient(stops: [
                .init(color: style.haloColor.opacity(0.75 * intensity), location: 0.0),
                .init(color: style.outerColor.opacity(0.35 * intensity), location: 0.45),
                .init(color: .clear, location: 1.0),
            ]),
            center: CGPoint(x: cx, y: baseY),
            startRadius: 0,
            endRadius: r
        ))
    }

    // 2. Smoke — drifting grey-blue particles above the flame
    private func drawSmoke(
        into context: inout GraphicsContext,
        cx: CGFloat, baseY: CGFloat, scale: CGFloat,
        time t: TimeInterval, intensity: Double
    ) {
        let count = Int(40 * style.smokeIntensity * intensity)
        let topY = baseY - scale * style.height
        for i in 0 ..< count {
            let seed = Double(i) * 17.273
            let life = (t * 0.18 + seed * 0.13).truncatingRemainder(dividingBy: 1.0)
            let drift = sin(seed + t * 0.5) * scale * 0.10
            let x = cx + drift + sin(life * 6.28 + seed) * scale * 0.04
            let y = topY - life * scale * 0.55
            let r = scale * (0.012 + life * 0.030)
            let opacity = (0.18 - life * 0.18) * style.smokeIntensity * intensity
            let circle = Path(ellipseIn: CGRect(
                x: x - r, y: y - r, width: r * 2, height: r * 2
            ))
            context.fill(circle, with: .color(Color(hex: 0x3A322B).opacity(max(0, opacity))))
        }
    }

    // 3 & 4. Outer + body — multiple lobes, turbulence-displaced
    private func drawFlameBody(
        into context: inout GraphicsContext,
        cx: CGFloat, baseY: CGFloat, scale: CGFloat,
        time t: TimeInterval, intensity: Double
    ) {
        let height = scale * style.height * intensity
        let baseW = scale * style.baseWidth

        for layer in 0 ..< 2 {
            let isBody = layer == 1
            let widthMul: CGFloat = isBody ? 0.7 : 1.0
            let opacity: Double = isBody ? 0.95 : 0.55

            for i in 0 ..< style.lobeCount {
                let phase = t * style.flickerRate + Double(i) * 1.7 + Double(layer) * 0.4
                let wobble = sin(phase) * style.flickerAmount
                let xJitter = sin(phase * 0.7 + Double(i)) * (scale * 0.04 * style.flickerAmount)
                let lobeWidth = baseW * widthMul * (0.7 + 0.3 * (Double(i + 1) / Double(style.lobeCount)))
                let lobeHeight = height * (0.55 + 0.45 * sin(phase * 0.4 + Double(i) * 0.6))
                let tipOffset = wobble * scale * 0.08

                var path = Path()
                let leftBase = CGPoint(x: cx - lobeWidth / 2 + xJitter, y: baseY)
                let rightBase = CGPoint(x: cx + lobeWidth / 2 + xJitter, y: baseY)
                let tip = CGPoint(x: cx + tipOffset, y: baseY - lobeHeight)
                let leftCtrl = CGPoint(x: cx - lobeWidth * 0.4 + xJitter,
                                       y: baseY - lobeHeight * 0.65)
                let rightCtrl = CGPoint(x: cx + lobeWidth * 0.4 + xJitter,
                                        y: baseY - lobeHeight * 0.65)
                path.move(to: leftBase)
                path.addQuadCurve(to: tip, control: leftCtrl)
                path.addQuadCurve(to: rightBase, control: rightCtrl)
                path.closeSubpath()

                let stops: [Gradient.Stop] = isBody ? [
                    .init(color: style.coreColor.opacity(opacity), location: 0.0),
                    .init(color: style.bodyColor.opacity(opacity), location: 0.45),
                    .init(color: style.outerColor.opacity(opacity * 0.7), location: 0.85),
                    .init(color: .clear, location: 1.0),
                ] : [
                    .init(color: style.bodyColor.opacity(opacity), location: 0.0),
                    .init(color: style.outerColor.opacity(opacity * 0.6), location: 0.7),
                    .init(color: .clear, location: 1.0),
                ]
                context.fill(path, with: .linearGradient(
                    Gradient(stops: stops),
                    startPoint: CGPoint(x: cx, y: baseY),
                    endPoint: tip
                ))
            }
        }
    }

    // 5. Core — bright inner sliver, additive blend
    private func drawCore(
        into context: inout GraphicsContext,
        cx: CGFloat, baseY: CGFloat, scale: CGFloat,
        time t: TimeInterval, intensity: Double
    ) {
        let phase = sin(t * style.flickerRate * 1.4) * 0.5 + 0.5
        let h = scale * style.height * 0.32 * intensity * (0.85 + 0.15 * phase)
        let w = scale * style.baseWidth * 0.32 * (0.85 + 0.15 * phase)
        var path = Path()
        path.move(to: CGPoint(x: cx - w / 2, y: baseY))
        path.addQuadCurve(
            to: CGPoint(x: cx + w / 2, y: baseY),
            control: CGPoint(x: cx, y: baseY - h)
        )
        var core = context
        core.blendMode = .plusLighter
        core.fill(path, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.95), style.coreColor.opacity(0.0)]),
            startPoint: CGPoint(x: cx, y: baseY),
            endPoint: CGPoint(x: cx, y: baseY - h)
        ))
    }

    // 6. Sparks — rising flecks
    private func drawSparks(
        into context: inout GraphicsContext,
        cx: CGFloat, baseY: CGFloat, scale: CGFloat,
        time t: TimeInterval, intensity: Double
    ) {
        let count = Int(style.sparkRate * 1.5 * intensity)
        for i in 0 ..< count {
            let seed = Double(i) * 13.139
            let life = (t * 0.55 + seed * 0.21).truncatingRemainder(dividingBy: 1.0)
            let xOffset = sin(seed * 6.28 + t * 1.2) * scale * 0.18 * style.flickerAmount
            let yOffset = -life * scale * 0.85
            let r = scale * 0.005 * (1.0 - life)
            let alpha = (0.7 - life * 0.7) * intensity
            let dot = Path(ellipseIn: CGRect(
                x: cx + xOffset - r,
                y: baseY + yOffset - r,
                width: r * 2, height: r * 2
            ))
            context.fill(dot, with: .color(style.bodyColor.opacity(alpha)))
        }
    }
}

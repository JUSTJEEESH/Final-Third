import SwiftUI

/// The Lighting Ceremony — the emotional anchor of the app. Method-aware:
/// the flame, the haptic, the timing, and the cigar foot ember all change
/// with which lighting tool the user picked.
///
/// Composition (back to front):
///   - Pure black canvas + warm radial vignette
///   - Soft floor glow
///   - Cigar (CigarFootView) drifts in from the right
///   - Lighting tool (SF Symbol) drifts in from below + left
///   - Flame ignites between them
///   - Flame's intensity climbs over `style.ignitionDuration`
///   - Cigar foot ember bloom syncs to flame intensity
///   - Tool fades out as the flame establishes
///   - Cigar settles centered, name + vitola fade in at `style.revealAt`
///   - "Tap to take your seat." appears at `style.promptAt` with breathe loop
struct LightingCeremonyView: View {
    let cigar: Cigar?
    let method: Session.LightingMethod
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed: Double = 0
    @State private var nameVisible = false
    @State private var promptVisible = false
    @State private var didTriggerHaptics = false

    private var style: FlameStyle { FlameStyle.forMethod(method) }

    var body: some View {
        ZStack {
            background
            scene
            cigarReveal
            promptOverlay
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if promptVisible {
                HapticsService.shared.tap()
                onComplete()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Lighting your \(cigar?.displayName ?? "cigar") with a \(style.toolName.lowercased()). Double tap to enter."
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onComplete() }
        .onAppear { runChoreography() }
    }

    // MARK: Background — black + warm vignette + faint atmosphere

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [
                    style.haloColor.opacity(0.18 * floorGlowIntensity),
                    .clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.85),
                startRadius: 40, endRadius: 600
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [.clear, .black.opacity(0.92)],
                center: .center, startRadius: 80, endRadius: 600
            )
            .ignoresSafeArea()
            .opacity(min(elapsed / 0.4, 1))
        }
    }

    // MARK: Main scene — cigar + flame + tool

    private var scene: some View {
        GeometryReader { geo in
            let centerY = geo.size.height * 0.55

            ZStack {
                // Cigar — drifts from the right, settles slightly left of center
                CigarFootView(ignitedAmount: emberAmount)
                    .offset(x: cigarXOffset(width: geo.size.width),
                            y: centerY - geo.size.height / 2)

                // Flame — sized to canvas, anchored under the cigar foot
                if !reduceMotion {
                    FlameCanvas(style: style, intensity: flameIntensity)
                        .frame(width: 220, height: 260)
                        .offset(x: -geo.size.width * 0.08,
                                y: centerY - geo.size.height / 2 - 70)
                        .blendMode(.plusLighter)
                        .opacity(elapsed > 0.5 ? 1 : 0)
                } else {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 86))
                        .foregroundStyle(style.bodyColor)
                        .offset(x: -geo.size.width * 0.08,
                                y: centerY - geo.size.height / 2 - 50)
                        .opacity(elapsed > 0.5 ? 1 : 0)
                }

                // Lighting tool — drifts in from below
                tool
                    .offset(x: -geo.size.width * 0.18,
                            y: centerY - geo.size.height / 2 + toolYOffset)
                    .opacity(toolOpacity)
            }
        }
    }

    private var tool: some View {
        VStack(spacing: 6) {
            Image(systemName: style.toolSymbol)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(LinearGradient(
                    colors: [style.coreColor, style.bodyColor, style.outerColor],
                    startPoint: .top, endPoint: .bottom
                ))
            Text(style.toolName.uppercased())
                .font(FTType.caption(9, weight: .semibold))
                .tracking(2)
                .foregroundStyle(FTColor.gold.opacity(0.7))
        }
    }

    // MARK: Cigar name reveal

    private var cigarReveal: some View {
        VStack(spacing: FTSpace.xs) {
            Spacer()
            if let cigar {
                Text(cigar.brand.uppercased())
                    .font(FTType.caption(11, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(FTColor.gold.opacity(0.9))
                Text(cigar.line)
                    .font(FTType.display(34))
                    .foregroundStyle(FTColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FTSpace.xl)
                if let vitola = cigar.vitola {
                    Text(vitola)
                        .font(FTType.body(14))
                        .foregroundStyle(FTColor.inkMuted)
                }
            }
            Text(style.methodCopy)
                .font(FTType.caption(11))
                .foregroundStyle(FTColor.inkFaint)
                .padding(.top, FTSpace.xs)
            Spacer().frame(height: 130)
        }
        .opacity(nameVisible ? 1 : 0)
        .animation(FTMotion.easeOutSoft, value: nameVisible)
    }

    private var promptOverlay: some View {
        VStack {
            Spacer()
            Text("Tap to take your seat.")
                .font(FTType.caption(13))
                .tracking(1.4)
                .foregroundStyle(FTColor.gold.opacity(promptVisible ? 0.9 : 0))
                .padding(.bottom, FTSpace.xxl)
                .scaleEffect(promptVisible ? 1.0 : 0.95)
                .animation(promptVisible ? FTMotion.breatheCurve : .default,
                           value: promptVisible)
        }
    }

    // MARK: Choreography

    private func runChoreography() {
        if !didTriggerHaptics {
            didTriggerHaptics = true
            HapticsService.shared.playLightingPattern(for: method)
        }
        Task { @MainActor in
            let frame = 1.0 / 60.0
            var t: Double = 0
            while t < style.totalDuration + 0.5 {
                try? await Task.sleep(for: .seconds(frame))
                t += frame
                elapsed = t
                if t >= style.revealAt && !nameVisible { nameVisible = true }
                if t >= style.promptAt && !promptVisible { promptVisible = true }
            }
        }
    }

    // MARK: Phase math

    private var flameIntensity: Double {
        let start = 0.4
        let p = max(0, min((elapsed - start) / style.ignitionDuration, 1))
        // Eased ramp + slight breath
        let eased = p * p * (3 - 2 * p)   // smoothstep
        let breath = 0.05 * sin(elapsed * style.breathRate * 2)
        return min(max(eased + breath, 0), 1)
    }

    private var emberAmount: Double {
        // Ember bloom trails the flame slightly so the cigar lights *after*
        // the flame is established. Scales 0…1 over (start+0.4)…full.
        let start = 0.6
        let p = max(0, min((elapsed - start) / (style.ignitionDuration + 0.3), 1))
        return p * p
    }

    private var floorGlowIntensity: Double {
        flameIntensity * 0.85 + (sin(elapsed * 1.4) * 0.05)
    }

    /// Cigar drifts in from the right of the screen, settles slightly past
    /// center where the flame can meet it.
    private func cigarXOffset(width: CGFloat) -> CGFloat {
        let p = max(0, min(elapsed / 1.4, 1))
        let eased = 1 - pow(1 - p, 3)
        let from: CGFloat = width * 0.6
        let to: CGFloat = width * 0.05
        return from + (to - from) * CGFloat(eased)
    }

    private var toolYOffset: CGFloat {
        let p = max(0, min((elapsed - 0.2) / 0.7, 1))
        let eased = 1 - pow(1 - p, 2)
        return 220 * (1 - CGFloat(eased))
    }

    private var toolOpacity: Double {
        let appear = max(0, min((elapsed - 0.2) / 0.5, 1))
        let fade = max(0, 1 - max(0, (elapsed - (style.ignitionDuration + 0.5)) / 0.6))
        return appear * fade
    }
}

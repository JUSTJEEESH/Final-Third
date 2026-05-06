import SwiftUI

/// The Lighting Ceremony — full-screen ritual moment played before a session
/// begins. Choreographed across ~6 s, with Reduce Motion fallback.
///
/// Phases (relative seconds):
///   0.0  vignette in, dim
///   0.4  lighting tool slides in, ignition tick haptic, match strike SFX
///   0.9  flame ignites, whoosh + low rumble haptic
///   1.6  cigar foot glow + ember bloom
///   3.0  cigar name + vitola fade in
///   5.5  settle pulse haptic, "tap to enter" prompt
struct LightingCeremonyView: View {
    let cigar: Cigar?
    let method: Session.LightingMethod
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed: Double = 0
    @State private var nameVisible = false
    @State private var promptVisible = false
    @State private var didTriggerHaptics = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Vignette
            RadialGradient(
                colors: [.clear, .black.opacity(0.85)],
                center: .center, startRadius: 80, endRadius: 540
            )
            .ignoresSafeArea()
            .opacity(min(elapsed / 0.4, 1))

            // Lighting tool sliding in
            lightingTool
                .offset(y: toolOffset)
                .opacity(toolOpacity)

            // Flame
            if !reduceMotion {
                FlameCanvas(intensity: flameIntensity)
                    .frame(maxWidth: 320, maxHeight: 320)
                    .offset(y: -32)
                    .opacity(elapsed > 0.9 ? 1 : 0)
                    .blendMode(.plusLighter)
            } else {
                Image(systemName: "flame.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(LinearGradient(
                        colors: [FTColor.emberCore, FTColor.emberHot, FTColor.ember],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .opacity(elapsed > 0.9 ? 1 : 0)
            }

            // Cigar reveal
            VStack(spacing: FTSpace.xs) {
                Spacer()
                if let cigar {
                    Text(cigar.brand.uppercased())
                        .font(FTType.caption(11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(FTColor.gold.opacity(0.9))
                    Text(cigar.line)
                        .font(FTType.display(34))
                        .foregroundStyle(FTColor.ink)
                    if let vitola = cigar.vitola {
                        Text(vitola).font(FTType.body(15)).foregroundStyle(FTColor.inkMuted)
                    }
                }
                Spacer().frame(height: 80)
            }
            .opacity(nameVisible ? 1 : 0)
            .animation(FTMotion.easeOutSoft, value: nameVisible)

            // Tap to enter
            VStack {
                Spacer()
                Text("Tap to take your seat.")
                    .font(FTType.caption(13))
                    .foregroundStyle(FTColor.gold.opacity(0.8))
                    .padding(.bottom, FTSpace.xxl)
                    .opacity(promptVisible ? 1 : 0)
                    .animation(FTMotion.breatheCurve, value: promptVisible)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if promptVisible {
                HapticsService.shared.tap()
                onComplete()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lighting your \(cigar?.displayName ?? "cigar"). Double tap to enter.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onComplete() }
        .onAppear { runChoreography() }
    }

    // MARK: Choreography

    private func runChoreography() {
        if !didTriggerHaptics {
            didTriggerHaptics = true
            HapticsService.shared.playLightingPattern()
        }

        // Drive a manual elapsed clock so we can phase visuals precisely.
        Task { @MainActor in
            let frameInterval: Double = 1.0 / 60.0
            var t: Double = 0
            while t < 6.5 {
                try? await Task.sleep(for: .seconds(frameInterval))
                t += frameInterval
                elapsed = t
                if t >= 3.0 && !nameVisible { nameVisible = true }
                if t >= 5.5 && !promptVisible { promptVisible = true }
            }
        }
    }

    // MARK: Phase math

    private var flameIntensity: Double {
        // ramp 0 → 1 between 0.9 and 1.8 s, then breathe ±10%
        let base = max(0, min((elapsed - 0.9) / 0.9, 1))
        let breathe = 0.1 * sin(elapsed * 2.4)
        return min(max(base + breathe, 0), 1)
    }

    private var toolOffset: CGFloat {
        let p = max(0, min((elapsed - 0.2) / 0.6, 1))
        return 200 * (1 - p)
    }

    private var toolOpacity: Double {
        // Fade out tool once flame is established
        let inOpacity = max(0, min((elapsed - 0.2) / 0.4, 1))
        let outOpacity = max(0, 1 - max(0, (elapsed - 1.8) / 0.6))
        return inOpacity * outOpacity
    }

    @ViewBuilder
    private var lightingTool: some View {
        let symbol: String = {
            switch method {
            case .match: return "fireworks"
            case .torch: return "flame.fill"
            case .cedar: return "leaf.fill"
            case .softFlame: return "circle.fill"
            }
        }()
        Image(systemName: symbol)
            .font(.system(size: 42))
            .foregroundStyle(FTColor.gold)
            .padding(.top, 220)
    }
}

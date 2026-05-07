import SwiftUI

/// The Patron upsell. One screen, no comparison table, no urgency
/// timer. Dim leather, gold trim, three rotating value lines, monthly
/// and annual prices side-by-side, single primary CTA per option, a
/// quiet "Restore purchases" link, and the legal fine print.
///
/// Brand voice: hospitality, not marketing. We're inviting you to be
/// a patron of the house, not selling you a feature pack.
///
/// Trigger strings flow into analytics so we can see which rooms /
/// moments convert: "voice_room_card", "audio_theme_locked",
/// "host_room_attempt", "journal_30_day_cap", etc.
struct PatronSheet: View {
    let trigger: String

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var lineIndex = 0
    @State private var isWorking = false
    @State private var pendingProductID: String?
    @State private var error: String?

    /// Three lines that rotate every ~3.5s. Reads as a whisper of
    /// what the house has to offer, not a feature checklist.
    private static let rotatingLines: [String] = [
        "Voice rooms. Hold to talk. Never always-on.",
        "Host your own room. The lounge keeps growing.",
        "Five usuals saved, not one. Tuesdays look different.",
        "All ambience — Jazz, Rain, Fireplace, seasonal.",
        "Your full Journal, kept forever.",
    ]

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            TexturePanel(texture: .leather, opacity: 0.14, zoom: 1.6)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            // Soft warm glow, like the home flame button afterimage.
            RadialGradient(
                colors: [FTColor.gold.opacity(0.14), .clear],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 0, endRadius: 480
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: FTSpace.xxl) {
                    header
                    rotatingLine
                    pricingRow
                    cta
                    restoreLink
                    fineprint
                }
                .padding(.horizontal, FTSpace.xl)
                .padding(.top, FTSpace.xxxl)
                .padding(.bottom, FTSpace.xxl)
            }

            closeButton
        }
        .preferredColorScheme(.dark)
        .task {
            container.analytics.track(.paywallShown(trigger: trigger))
            startLineRotation()
        }
    }

    // MARK: - Pieces

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    HapticsService.shared.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FTColor.ink)
                        .frame(width: 36, height: 36)
                        .background(FTColor.surfaceHi.opacity(0.85))
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(FTColor.divider, lineWidth: FTStroke.hairline)
                        )
                }
                .accessibilityLabel("Close")
                .padding(.top, FTSpace.md)
                .padding(.trailing, FTSpace.lg)
            }
            Spacer()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FTSpace.md) {
            HStack(spacing: 10) {
                // Single gold pip — the Patron mark in miniature.
                Circle()
                    .stroke(FTColor.gold.opacity(0.9), lineWidth: 1)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(FTColor.surfaceHi))
                    .shadow(color: FTColor.goldGlow.opacity(0.5), radius: 4)
                Text("THE PATRON")
                    .font(FTType.caption(11, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(FTColor.gold)
            }

            Text("Become a patron of the house.")
                .font(FTType.display(28, weight: .semibold))
                .foregroundStyle(FTColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("The ritual is yours. The room is yours. The Journal is yours, forever. Patrons keep the lights on and the rooms growing.")
                .font(FTType.body(14))
                .foregroundStyle(FTColor.inkMuted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Three lines, fading in/out every few seconds. Quieter than a
    /// bullet list, more atmospheric.
    private var rotatingLine: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(FTColor.gold.opacity(0.8))
                Text(Self.rotatingLines[lineIndex])
                    .font(FTType.body(15, weight: .medium))
                    .foregroundStyle(FTColor.ink)
                    .id(lineIndex)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, FTSpace.lg)
            .padding(.horizontal, FTSpace.lg)
            .background(FTColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.md, style: .continuous)
                    .stroke(FTColor.gold.opacity(0.25), lineWidth: 0.5)
            )
        }
    }

    private var pricingRow: some View {
        HStack(spacing: FTSpace.md) {
            priceCard(
                title: "MONTHLY",
                price: "$7.99",
                cadence: "per month",
                tagline: nil,
                isAnnual: false
            )
            priceCard(
                title: "ANNUAL",
                price: "$59",
                cadence: "per year",
                tagline: "14-day free trial · save $36",
                isAnnual: true
            )
        }
    }

    private func priceCard(
        title: String,
        price: String,
        cadence: String,
        tagline: String?,
        isAnnual: Bool
    ) -> some View {
        Button {
            HapticsService.shared.tap()
            Task { await purchase(annual: isAnnual) }
        } label: {
            VStack(alignment: .leading, spacing: FTSpace.sm) {
                Text(title)
                    .font(FTType.caption(10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(isAnnual ? FTColor.gold : FTColor.inkMuted)
                Text(price)
                    .font(FTType.display(28, weight: .semibold))
                    .foregroundStyle(FTColor.ink)
                Text(cadence)
                    .font(FTType.caption(11))
                    .foregroundStyle(FTColor.inkMuted)
                if let tagline {
                    Text(tagline)
                        .font(FTType.caption(11, weight: .semibold))
                        .foregroundStyle(FTColor.gold)
                        .padding(.top, 4)
                }
                if isWorking, pendingProductID == (isAnnual ? Self.annualID : Self.monthlyID) {
                    HStack {
                        Spacer()
                        ProgressView().tint(FTColor.gold)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FTSpace.lg)
            .background {
                if isAnnual { GoldHaloBackground() } else { FTColor.surface }
            }
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous)
                    .stroke(
                        isAnnual ? FTColor.gold.opacity(0.6) : FTColor.divider,
                        lineWidth: isAnnual ? 1 : FTStroke.hairline
                    )
            )
            .shadow(color: isAnnual ? FTColor.goldGlow.opacity(0.3) : .clear, radius: 14)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .accessibilityLabel("\(title), \(price) \(cadence)\(tagline.map { ". \($0)" } ?? "")")
    }

    private var cta: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            if let error {
                Text(error)
                    .font(FTType.caption(12))
                    .foregroundStyle(FTColor.danger)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private var restoreLink: some View {
        Button {
            HapticsService.shared.tap()
            Task { await restore() }
        } label: {
            Text("Restore purchases")
                .font(FTType.caption(12, weight: .medium))
                .foregroundStyle(FTColor.inkMuted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
    }

    private var fineprint: some View {
        VStack(spacing: 4) {
            Text("Auto-renews. Cancel any time in Settings.")
                .font(FTType.caption(10))
                .foregroundStyle(FTColor.inkFaint)
            Text("The ritual is always free. Patrons unlock depth — never the door.")
                .font(FTType.caption(10))
                .italic()
                .foregroundStyle(FTColor.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Behavior

    /// RevenueCat package identifier conventions. `$rc_monthly` and
    /// `$rc_annual` are the well-known IDs configured in the RC
    /// dashboard's "current offering."
    private static let monthlyID = "$rc_monthly"
    private static let annualID = "$rc_annual"

    private func startLineRotation() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                if Task.isCancelled { break }
                withAnimation(.easeInOut(duration: 0.6)) {
                    lineIndex = (lineIndex + 1) % Self.rotatingLines.count
                }
            }
        }
    }

    private func purchase(annual: Bool) async {
        let id = annual ? Self.annualID : Self.monthlyID
        pendingProductID = id
        isWorking = true
        defer { isWorking = false; pendingProductID = nil }
        do {
            try await container.entitlements.purchase(packageIdentifier: id)
            if container.entitlements.isPremium {
                container.analytics.track(.paywallPurchased(
                    productID: container.entitlements.activeProductID ?? id
                ))
                HapticsService.shared.success()
                dismiss()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func restore() async {
        do {
            try await container.entitlements.restore()
            if container.entitlements.isPremium { dismiss() }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Background

/// Gold-tinted card surface for the annual price card. The same warm
/// gradient + leather grain we use on Live cards in the doorway sheet,
/// dialled up so the recommended option pulls the eye without
/// shouting.
private struct GoldHaloBackground: View {
    var body: some View {
        ZStack {
            FTColor.surfaceHi
            TexturePanel(texture: .leather, opacity: 0.16, zoom: 1.5)
                .allowsHitTesting(false)
            LinearGradient(
                colors: [
                    FTColor.gold.opacity(0.18),
                    FTColor.ember.opacity(0.05),
                    .clear,
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

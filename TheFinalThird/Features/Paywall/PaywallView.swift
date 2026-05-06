import SwiftUI

struct PaywallView: View {
    let trigger: String

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        ZStack {
            FTColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: FTSpace.lg) {
                    header
                    benefits
                    Spacer().frame(height: FTSpace.lg)
                    cta
                    fineprint
                }
                .padding(FTSpace.xl)
            }
        }
        .onAppear { container.analytics.track(.paywallShown(trigger: trigger)) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FTSpace.sm) {
            Text("Members")
                .font(FTType.caption(11, weight: .semibold))
                .foregroundStyle(FTColor.gold)
                .tracking(2)
                .textCase(.uppercase)
            Text("Keep your chair.")
                .font(FTType.display(34))
                .foregroundStyle(FTColor.gold)
            Text(container.config.string("paywall.copy")
                ?? "Members keep their journal forever, host private rooms, and unlock pairings.")
                .font(FTType.body(15))
                .foregroundStyle(FTColor.ink.opacity(0.85))
        }
        .padding(.top, FTSpace.lg)
    }

    private var benefits: some View {
        VStack(spacing: FTSpace.sm) {
            benefit("Full journal history", system: "book.closed.fill")
            benefit("Host private rooms", system: "lock.shield.fill")
            benefit("Pairings & sommelier picks", system: "wineglass")
            benefit("Advanced ritual settings", system: "moon.stars.fill")
        }
    }

    private func benefit(_ text: String, system: String) -> some View {
        FTCard {
            HStack(spacing: FTSpace.md) {
                Image(systemName: system)
                    .foregroundStyle(FTColor.gold)
                    .frame(width: 24)
                Text(text).font(FTType.body(15))
                Spacer()
            }
        }
    }

    private var cta: some View {
        VStack(spacing: FTSpace.sm) {
            FTButton(title: "Become a member", style: .gold, isLoading: isWorking) {
                Task {
                    isWorking = true; defer { isWorking = false }
                    do {
                        try await container.entitlements.purchase(packageIdentifier: "$rc_monthly")
                        if container.entitlements.isPremium {
                            container.analytics.track(.paywallPurchased(productID:
                                container.entitlements.activeProductID ?? "unknown"))
                            dismiss()
                        }
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            FTButton(title: "Restore purchases", style: .ghost) {
                Task {
                    do { try await container.entitlements.restore() }
                    catch { self.error = error.localizedDescription }
                }
            }
            if let error {
                Text(error).font(FTType.caption(12)).foregroundStyle(FTColor.danger)
            }
        }
    }

    private var fineprint: some View {
        Text("Auto-renews. Cancel anytime in Settings.")
            .font(FTType.caption(11))
            .foregroundStyle(FTColor.inkFaint)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// Convenience modifier — gates a feature behind premium with a paywall sheet.
struct PremiumGateModifier: ViewModifier {
    let isPremium: Bool
    let trigger: String
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .disabled(!isPremium)
            .opacity(isPremium ? 1 : 0.5)
            .overlay(alignment: .center) {
                if !isPremium {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticsService.shared.tap()
                            showPaywall = true
                        }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView(trigger: trigger) }
    }
}

extension View {
    func premiumGate(isPremium: Bool, trigger: String) -> some View {
        modifier(PremiumGateModifier(isPremium: isPremium, trigger: trigger))
    }
}

import SwiftUI

/// Compatibility shim — the original M-era PaywallView has been
/// retired in favor of `PatronSheet`. Existing callers
/// (`PaywallView(trigger:)`) keep working because this struct just
/// re-presents PatronSheet under the same name. New code should use
/// `PatronSheet` directly.
struct PaywallView: View {
    let trigger: String
    var body: some View { PatronSheet(trigger: trigger) }
}

/// Convenience modifier — gates a feature behind Patron with the
/// PatronSheet upsell.
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
            .sheet(isPresented: $showPaywall) { PatronSheet(trigger: trigger) }
    }
}

extension View {
    func premiumGate(isPremium: Bool, trigger: String) -> some View {
        modifier(PremiumGateModifier(isPremium: isPremium, trigger: trigger))
    }
}

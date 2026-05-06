import Foundation
import RevenueCat

/// Source of truth for premium status (PRD §19). Mirrors RC entitlements
/// onto the in-memory `isPremium` flag used by feature gating.
@MainActor
@Observable
final class EntitlementService {
    private(set) var isPremium: Bool = false
    private(set) var activeProductID: String?
    private(set) var renewsAt: Date?

    /// Whether RevenueCat was actually configured. False during local dev
    /// when REVENUECAT_API_KEY_IOS is the placeholder; calls into Purchases
    /// are skipped and treated as "free tier" so the rest of the app runs
    /// without the SDK spamming the console with credential errors.
    private(set) var isConfigured: Bool = false

    init() {}

    func bootstrap(appUserID: String?) {
        let key = SupabaseEnv.shared.revenueCatAPIKey
        guard isRealKey(key) else {
            isConfigured = false
            return
        }
        Purchases.logLevel = .info
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: key)
                .with(appUserID: appUserID)
                .build()
        )
        isConfigured = true
        Task { await refresh() }
    }

    func refresh() async {
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
        } catch {
            isPremium = false
        }
    }

    func purchase(packageIdentifier: String) async throws {
        guard isConfigured else { throw AppError.unknown("Purchases not configured.") }
        let offerings = try await Purchases.shared.offerings()
        guard let pkg = offerings.current?.availablePackages
            .first(where: { $0.identifier == packageIdentifier })
        else { throw AppError.notFound(entity: "Package") }
        let result = try await Purchases.shared.purchase(package: pkg)
        apply(result.customerInfo)
    }

    func restore() async throws {
        guard isConfigured else { throw AppError.unknown("Purchases not configured.") }
        let info = try await Purchases.shared.restorePurchases()
        apply(info)
    }

    private func apply(_ info: CustomerInfo) {
        let active = info.entitlements.active
        isPremium = !active.isEmpty
        activeProductID = active.values.first?.productIdentifier
        renewsAt = active.values.first?.expirationDate
    }

    /// RC keys begin with `appl_` (iOS) or `goog_` (Android). The xcconfig
    /// example ships with `appl_placeholder` — treat that as not configured.
    private func isRealKey(_ key: String) -> Bool {
        key.hasPrefix("appl_") && key != "appl_placeholder"
    }
}

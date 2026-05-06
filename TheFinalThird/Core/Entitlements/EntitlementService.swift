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

    init() {}

    func bootstrap(appUserID: String?) {
        Purchases.logLevel = .info
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: SupabaseEnv.shared.revenueCatAPIKey)
                .with(appUserID: appUserID)
                .build()
        )
        Task { await refresh() }
    }

    func refresh() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
        } catch {
            isPremium = false
        }
    }

    func purchase(packageIdentifier: String) async throws {
        let offerings = try await Purchases.shared.offerings()
        guard let pkg = offerings.current?.availablePackages
            .first(where: { $0.identifier == packageIdentifier })
        else { throw AppError.notFound(entity: "Package") }
        let result = try await Purchases.shared.purchase(package: pkg)
        apply(result.customerInfo)
    }

    func restore() async throws {
        let info = try await Purchases.shared.restorePurchases()
        apply(info)
    }

    private func apply(_ info: CustomerInfo) {
        let active = info.entitlements.active
        isPremium = !active.isEmpty
        activeProductID = active.values.first?.productIdentifier
        renewsAt = active.values.first?.expirationDate
    }
}

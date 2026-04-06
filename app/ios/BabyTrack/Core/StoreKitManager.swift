import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var hasActiveSubscription: Bool = UserDefaults.standard.bool(forKey: "subscription.active")

    private var planToProductId: [String: String] = [:]
    private let fallbackPlanToProductId: [String: String] = [
        "monthly": "com.babytrack.premium.monthly",
        "annual": "com.babytrack.premium.annual",
        "family_annual": "com.babytrack.premium.family.annual"
    ]
    private let fallbackProductIds: [String] = [
        "com.babytrack.premium.monthly",
        "com.babytrack.premium.annual",
        "com.babytrack.premium.family.annual"
    ]

    func configure(with offers: PaywallOffersResponse) async {
        let mapped = offers.plans.reduce(into: fallbackPlanToProductId) { result, plan in
            let configured = plan.appStoreProductId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !configured.isEmpty {
                result[plan.id] = configured
            } else if result[plan.id] == nil, let fallback = fallbackPlanToProductId[plan.id] {
                result[plan.id] = fallback
            }
        }
        planToProductId = mapped

        let ids = Array(Set(mapped.values + fallbackProductIds)).sorted()
        await loadProducts(ids: ids)
    }

    func product(for planId: String) -> Product? {
        if let productId = planToProductId[planId] {
            return products.first(where: { $0.id == productId })
        }
        return nil
    }

    func loadProducts(ids: [String]? = nil) async {
        let targetIds = ids ?? fallbackProductIds
        do {
            let fetched = try await Product.products(for: targetIds)
            products = fetched.sorted(by: { $0.displayName < $1.displayName })
        } catch {
            products = []
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified:
                    hasActiveSubscription = true
                    UserDefaults.standard.set(true, forKey: "subscription.active")
                case .unverified:
                    break
                }
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            // no-op for now
        }
    }

    func restore() async {
        try? await AppStore.sync()
    }
}

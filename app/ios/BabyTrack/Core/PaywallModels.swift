import Foundation

struct PaywallOffersResponse: Codable {
    let version: String
    let defaultPlan: String
    let plans: [PaywallPlan]
}

struct PaywallPlan: Codable, Identifiable {
    let id: String
    let title: String
    let appStoreProductId: String?
    let price: String
    let currency: String
    let trialDays: Int
    let badge: String?
}

final class PaywallOffersLoader {
    static func loadLocal() -> PaywallOffersResponse {
        guard let url = Bundle.main.url(forResource: "paywall_offers", withExtension: "json", subdirectory: "Config"),
              let data = try? Data(contentsOf: url),
              let parsed = try? JSONDecoder().decode(PaywallOffersResponse.self, from: data) else {
            return PaywallOffersResponse(version: "fallback", defaultPlan: "annual", plans: [])
        }
        return parsed
    }
}

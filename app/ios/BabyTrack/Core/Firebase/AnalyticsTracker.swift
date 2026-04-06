import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

enum AnalyticsEventName: String {
    case appOpen = "app_open"
    case onboardingCompleted = "onboarding_completed"
    case quickLogAdded = "quick_log_added"
    case paywallViewed = "paywall_viewed"
    case trialStarted = "trial_started"
    case syncCompleted = "sync_completed"
    case audioPlayed = "audio_played"
}

final class AnalyticsTracker {
    static let shared = AnalyticsTracker()
    private init() {}

    func track(_ event: AnalyticsEventName, params: [String: Any] = [:]) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.rawValue, parameters: params)
        #endif
    }
}

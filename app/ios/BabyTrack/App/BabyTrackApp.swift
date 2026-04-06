import SwiftUI

@main
struct BabyTrackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var eventStore = EventStore()
    @StateObject private var careSessionManager = CareSessionManager.shared
    @StateObject private var storeKit = StoreKitManager()
    @StateObject private var pushManager = PushNotificationManager.shared
    @StateObject private var authManager = AuthManager()
    @StateObject private var syncConflictStore = SyncConflictStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(eventStore)
                .environmentObject(careSessionManager)
                .environmentObject(storeKit)
                .environmentObject(authManager)
                .environmentObject(syncConflictStore)
                .task {
                    await authManager.bootstrap()
                    await appState.bootstrap(storeKit: storeKit)
                    await pushManager.requestAuthorizationAndRegister()
                }
                .preferredColorScheme(appState.theme.colorScheme)
                .environment(\.layoutDirection, appState.languageCode == "ar" ? .rightToLeft : .leftToRight)
        }
    }
}

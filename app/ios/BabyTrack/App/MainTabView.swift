import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            TodayHomeView()
                .tabItem {
                    Label(L10n.tr("app_today"), systemImage: "house")
                }
                .tag(AppTab.today)

            TimelineView()
                .tabItem {
                    Label(L10n.tr("app_timeline"), systemImage: "clock.arrow.circlepath")
                }
                .tag(AppTab.timeline)

            QuickAddView()
                .tabItem {
                    Label(L10n.tr("app_add"), systemImage: "plus.circle.fill")
                }
                .tag(AppTab.quickAdd)

            HealthView()
                .tabItem {
                    Label(L10n.tr("app_health"), systemImage: "heart.text.square")
                }
                .tag(AppTab.health)

            FamilyView()
                .tabItem {
                    Label(L10n.tr("app_family"), systemImage: "person.3")
                }
                .tag(AppTab.family)
        }
        // Use the project AccentColor so selected tab icon/text never become transparent.
        .tint(.accentColor)
        .onChange(of: appState.selectedTab) { _ in
            Haptics.light()
        }
    }
}

extension View {
    func staggerEntrance(show: Bool, delay: Double = 0) -> some View {
        self
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 16)
            .animation(
                .spring(response: 0.55, dampingFraction: 0.86, blendDuration: 0.1).delay(delay),
                value: show
            )
    }
}

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

struct PressableScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var opacity: Double = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? opacity : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

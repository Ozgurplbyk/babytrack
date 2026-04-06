import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var title: String {
        switch self {
        case .system: return L10n.tr("settings_theme_system")
        case .light: return L10n.tr("settings_theme_light")
        case .dark: return L10n.tr("settings_theme_dark")
        }
    }
}

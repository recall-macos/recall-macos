import Foundation
import SwiftUI

// MARK: - App Settings

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // General
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true
    @AppStorage("historyLimit") var historyLimit: Int = 100
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    // Appearance
    @AppStorage("colorScheme") var colorSchemeRaw: String = "system"

    // Privacy
    @AppStorage("historyExpirationHours") var historyExpirationHours: Int = 0 // 0 = never
    @AppStorage("excludedBundleIDs") private var excludedBundleIDsRaw: String = ""
    @AppStorage("isMonitoringPaused") var isMonitoringPaused: Bool = false

    // Keyboard shortcuts — Carbon modifier values (cmdKey=256, shiftKey=512, optionKey=2048, controlKey=4096)
    // Default: Cmd+Shift+V (cmdKey | shiftKey = 768)
    @AppStorage("globalShortcutKeyCode") var globalShortcutKeyCode: Int = 9   // V key
    @AppStorage("globalShortcutModifiers") var globalShortcutModifiers: Int = 768 // Cmd+Shift

    // Pro / monetization
    @AppStorage("isPro") var isPro: Bool = false

    var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var excludedBundleIDs: [String] {
        get {
            excludedBundleIDsRaw.isEmpty ? [] : excludedBundleIDsRaw.components(separatedBy: ",")
        }
        set {
            excludedBundleIDsRaw = newValue.joined(separator: ",")
        }
    }

    private init() {}
}

// MARK: - History Limit Options

enum HistoryLimit: Int, CaseIterable {
    case fifty = 50
    case hundred = 100
    case twoFifty = 250
    case fiveHundred = 500
    case thousand = 1000
    case unlimited = 0

    var displayName: String {
        switch self {
        case .fifty: return "50 items"
        case .hundred: return "100 items"
        case .twoFifty: return "250 items"
        case .fiveHundred: return "500 items"
        case .thousand: return "1000 items"
        case .unlimited: return "Unlimited"
        }
    }
}

// MARK: - History Expiration Options

enum HistoryExpiration: Int, CaseIterable {
    case oneHour = 1
    case oneDay = 24
    case sevenDays = 168
    case thirtyDays = 720
    case never = 0

    var displayName: String {
        switch self {
        case .oneHour: return "1 Hour"
        case .oneDay: return "1 Day"
        case .sevenDays: return "7 Days"
        case .thirtyDays: return "30 Days"
        case .never: return "Never"
        }
    }
}

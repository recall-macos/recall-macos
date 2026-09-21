import Foundation

extension Notification.Name {
    static let recallKeyEvent          = Notification.Name("recallKeyEvent")
    static let recallPanelShow         = Notification.Name("recallPanelShow")
    static let screenshotWatcherChanged = Notification.Name("recallScreenshotWatcherChanged")
}

enum RecallKeyEvent: String {
    case arrowUp, arrowDown, enter, cmdDelete, cmdP, cmdF, tabNext, tabPrev, tabDirect
    // quick-select digits 1-9: rawValue is "digit1" … "digit9"
    case digit1, digit2, digit3, digit4, digit5, digit6, digit7, digit8, digit9

    static func digit(for n: Int) -> RecallKeyEvent? {
        switch n {
        case 1: return .digit1; case 2: return .digit2; case 3: return .digit3
        case 4: return .digit4; case 5: return .digit5; case 6: return .digit6
        case 7: return .digit7; case 8: return .digit8; case 9: return .digit9
        default: return nil
        }
    }

    var digitIndex: Int? {
        switch self {
        case .digit1: return 0; case .digit2: return 1; case .digit3: return 2
        case .digit4: return 3; case .digit5: return 4; case .digit6: return 5
        case .digit7: return 6; case .digit8: return 7; case .digit9: return 8
        default: return nil
        }
    }
}

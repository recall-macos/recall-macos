import SwiftUI

// MARK: - App Entry Point

@main
struct RecallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — the app lives in the menu bar.
        // Settings opened programmatically from AppDelegate.
        Settings {
            SettingsView(
                store: appDelegate.store,
                monitor: appDelegate.monitor
            )
        }
    }
}

import AppKit

// MARK: - Paste Engine

/// Handles smart paste: restoring a clipboard item then pasting into the previous app.
final class PasteEngine {

    static let shared = PasteEngine()
    private init() {}

    /// Call immediately when the user triggers paste — don't defer to an asyncAfter chain.
    /// Writes the clipboard and brings the target app to front synchronously, then
    /// synthesizes Cmd+V after a brief settling window.
    @MainActor
    func paste(_ item: ClipboardItem, into previousApp: NSRunningApplication?, store: ClipboardStore) {
        // Fall back to the current frontmost app if lastActiveApp wasn't captured.
        let app = previousApp ?? NSWorkspace.shared.frontmostApplication
        guard let app, app != NSRunningApplication.current else { return }

        let pid = app.processIdentifier
        store.restoreToPasteboard(item)

        // Primary: Accessibility-based activation — works reliably on macOS 14/15
        // because it uses the AX framework directly rather than app activation APIs.
        // Requires Accessibility permission (granted during onboarding).
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, true as CFTypeRef)

        // Fallback: deprecated but still functional on most macOS versions.
        app.activate(options: .activateIgnoringOtherApps)

        // Synthesize Cmd+V after the panel dismiss animation (~0.12s) plus
        // a settling margin so the target window is actually key.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            PasteEngine.synthesizePaste(toPid: pid)
        }
    }

    static func synthesizePaste(toPid pid: pid_t) {
        let src = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.postToPid(pid)

        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.postToPid(pid)
    }
}

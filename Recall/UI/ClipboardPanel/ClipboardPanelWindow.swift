import AppKit

// MARK: - Clipboard Panel Window

// .nonactivatingPanel lets this panel become the KEY window (and thus receive
// all keyboard events) without requiring Recall to be the active/frontmost app.
// This is the definitive fix for keyboard navigation: sendEvent fires whenever
// the panel is key, regardless of which app is "active" in the Dock/switcher.

final class ClipboardPanelWindow: NSPanel {

    // Set by AppDelegate after buildPanel() — lets sendEvent update selection directly.
    weak var panelController: PanelController?

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.contentView = contentView
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovable = false
        self.isReleasedWhenClosed = false
        self.alphaValue = 0

        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 16
        contentView.layer?.masksToBounds = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        // Detect when the panel loses key status (user clicked another window)
        self.delegate = self
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Key interception
    // sendEvent runs BEFORE the responder chain. Because .nonactivatingPanel makes
    // this the key window without activating the app, sendEvent is the ONLY
    // reliable path for keyboard events — local monitors don't fire when the app
    // isn't active. Arrow keys call panelController directly; other keys post
    // notifications so the SwiftUI view can handle them.

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown else { super.sendEvent(event); return }

        let cmd  = event.modifierFlags.contains(.command)
        let char = event.charactersIgnoringModifiers?.lowercased()

        switch event.keyCode {
        case 126:                      // ↑
            panelController?.moveUp()
        case 125:                      // ↓
            panelController?.moveDown()
        case 115:                      // Home
            panelController?.jumpToFirst()
        case 119:                      // End
            panelController?.jumpToLast()
        case 36, 76:                   // Return / numpad Enter
            post(.enter)
        case 53:                       // Escape
            (NSApp.delegate as? AppDelegate)?.dismissPanel()
        case 51 where cmd:             // ⌘⌫
            post(.cmdDelete)
        case 123 where cmd:            // ⌘← → previous filter tab
            post(.tabPrev)
        case 124 where cmd:            // ⌘→ → next filter tab
            post(.tabNext)
        default:
            if cmd && char == "p" { post(.cmdP) }
            else if cmd && char == "f" { post(.cmdF) }
            else if cmd, let ch = char, ch >= "1", ch <= "6", let digit = Int(ch) {
                // ⌘1–⌘6 jump directly to a filter tab
                postTabDirect(digit - 1)
            } else if !cmd, !event.modifierFlags.contains(.control),
                    !event.modifierFlags.contains(.option),
                    let ch = char, ch >= "1", ch <= "9",
                    let digit = Int(ch), let key = RecallKeyEvent.digit(for: digit) {
                post(key)
            } else {
                super.sendEvent(event)
            }
        }
    }

    private func post(_ key: RecallKeyEvent) {
        NotificationCenter.default.post(
            name: .recallKeyEvent,
            object: nil,
            userInfo: ["key": key.rawValue]
        )
    }

    private func postTabDirect(_ index: Int) {
        NotificationCenter.default.post(
            name: .recallKeyEvent,
            object: nil,
            userInfo: ["key": RecallKeyEvent.tabDirect.rawValue, "tabIndex": index]
        )
    }

    // MARK: - Show

    func showCentered() {
        guard let screen = NSScreen.main else { return }
        let sr = screen.visibleFrame
        setFrameOrigin(NSPoint(x: sr.midX - frame.width / 2,
                               y: sr.midY - frame.height / 2))
        // With .nonactivatingPanel we don't need NSApp.activate().
        // makeKeyAndOrderFront makes the panel the key window directly.
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
    }

    // MARK: - Hide

    func animateOut() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.orderOut(nil)
        }
    }
}

// MARK: - NSWindowDelegate

extension ClipboardPanelWindow: NSWindowDelegate {
    // Fires when another window (in any app) becomes key — i.e. the user clicked
    // outside the panel. This replaces applicationDidResignActive for the close-on-
    // outside-click behaviour; it works correctly with .nonactivatingPanel because
    // the owning app was never "active" to begin with.
    func windowDidResignKey(_ notification: Notification) {
        (NSApp.delegate as? AppDelegate)?.panelWindowDidResignKey()
    }
}

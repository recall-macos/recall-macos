import AppKit
import SwiftUI
import ServiceManagement
import Combine

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - State

    let settings = AppSettings.shared
    let store: ClipboardStore
    let monitor: ClipboardMonitor
    let panelController = PanelController()

    private var statusItem: NSStatusItem?
    private var panelWindow: ClipboardPanelWindow?
    private var panelView: ClipboardPanelView?
    private var panelIsVisible = false
    private var clickOutsideMonitor: Any?
    private var expirationTimer: Timer?
    private var menuBarIconCancellable: AnyCancellable?
    private var shortcutCancellable: AnyCancellable?
    private var appearanceObservation: NSKeyValueObservation?

    // MARK: - Init

    override init() {
        self.store = ClipboardStore()
        self.monitor = ClipboardMonitor(store: store)
        super.init()
    }

    // MARK: - Lifecycle

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        store.flushPendingSave()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        applyStoredAppearance()
        startWatchingAppearance()
        setupMenuBar()
        syncMenuBarIcon()
        registerHotkey()
        syncShortcut()
        monitor.start()
        AdManager.shared.start()
        Task { @MainActor in store.pruneExpired() }
        startExpirationTimer()
        // Don't force screenshot redirect — user controls this in Settings > Privacy.
        // Forcing it on every launch kills the macOS bottom-right thumbnail preview.
        syncLaunchAtLogin()

        if !settings.hasCompletedOnboarding {
            showOnboarding()
        }
    }

    // MARK: - Appearance

    private func applyStoredAppearance() {
        switch settings.colorSchemeRaw {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":  NSApp.appearance = NSAppearance(named: .darkAqua)
        default:      NSApp.appearance = nil
        }
    }

    private func updateDockIcon() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            NSApp.applicationIconImage = NSImage(named: "AppIcon")
        } else {
            NSApp.applicationIconImage = NSImage(named: "AppIconLight")
        }
    }

    private func startWatchingAppearance() {
        updateDockIcon()
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateDockIcon() }
        }
    }

    // MARK: - Launch at Login

    private var launchAtLoginCancellable: AnyCancellable?

    func syncLaunchAtLogin() {
        applyLaunchAtLogin(settings.launchAtLogin)
        // @AppStorage doesn't expose a Combine publisher; observe UserDefaults directly.
        launchAtLoginCancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification, object: UserDefaults.standard)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyLaunchAtLogin(self.settings.launchAtLogin)
            }
    }

    private func applyLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // SMAppService throws when already in the desired state — safe to ignore.
        }
    }

    // MARK: - Menu Bar Icon Visibility

    func syncMenuBarIcon() {
        applyMenuBarIcon(settings.showMenuBarIcon)
        menuBarIconCancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification, object: UserDefaults.standard)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyMenuBarIcon(self.settings.showMenuBarIcon)
            }
    }

    private func applyMenuBarIcon(_ visible: Bool) {
        statusItem?.isVisible = visible
    }

    // MARK: - Expiration Timer

    private func startExpirationTimer() {
        expirationTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.store.pruneExpired() }
        }
    }

    // MARK: - Shortcut Sync

    private var lastRegisteredKeyCode: Int = -1
    private var lastRegisteredModifiers: Int = -1

    func syncShortcut() {
        shortcutCancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification, object: UserDefaults.standard)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let kc = self.settings.globalShortcutKeyCode
                let mo = self.settings.globalShortcutModifiers
                guard kc != self.lastRegisteredKeyCode || mo != self.lastRegisteredModifiers else { return }
                self.registerHotkey()
            }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Recall")
        button.image?.isTemplate = true
        button.action = #selector(menuBarButtonClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func menuBarButtonClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            statusItem?.menu = buildMenu()
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            togglePanel()
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Recall", action: #selector(togglePanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        let pause = NSMenuItem(
            title: monitor.isMonitoring ? "Pause Monitoring" : "Resume Monitoring",
            action: #selector(toggleMonitoring),
            keyEquivalent: ""
        )
        pause.target = self
        menu.addItem(pause)
        menu.addItem(.separator())

        let clear = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let about = NSMenuItem(title: "About Recall", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Recall", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    @objc private func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let alert = NSAlert()
        alert.messageText = "Recall"
        alert.informativeText = "Version \(version) (\(build))\n\nYour clipboard, always within reach.\n\nBuilt by Neel Verma"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func toggleMonitoring() {
        monitor.isMonitoring ? monitor.stop() : monitor.start()
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear History?"
        alert.informativeText = "This will delete all non-pinned clipboard items."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearAll()
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared(store: store, monitor: monitor).showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Hotkey

    func registerHotkey() {
        let kc = settings.globalShortcutKeyCode
        let mo = settings.globalShortcutModifiers
        lastRegisteredKeyCode = kc
        lastRegisteredModifiers = mo
        HotkeyManager.shared.register(keyCode: UInt32(kc), modifiers: UInt32(mo)) { [weak self] in
            // Carbon fires on the main thread — call directly so NSApp.activate()
            // runs inside the user-interaction context of the keypress. Using
            // DispatchQueue.main.async would defer past that context, causing
            // activate() to fail silently on macOS 14.
            MainActor.assumeIsolated { self?.togglePanel() }
        }
    }

    // MARK: - Panel

    @objc func togglePanel() {
        panelIsVisible ? dismissPanel() : showPanel()
    }

    // Called by ClipboardPanelWindow.windowDidResignKey when the panel loses
    // key status (user clicked another window). Works with .nonactivatingPanel
    // because it fires on key-window change, not app-activation change.
    func panelWindowDidResignKey() {
        guard panelIsVisible else { return }
        panelIsVisible = false
        removeClickOutsideMonitor()
        panelWindow?.animateOut()
    }

    private func removeClickOutsideMonitor() {
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m); clickOutsideMonitor = nil }
    }

    func showPanel() {
        guard !panelIsVisible else { return }
        monitor.captureActiveApp()
        if panelWindow == nil { buildPanel() }
        panelIsVisible = true
        panelWindow?.showCentered()

        // Global monitor fires for any click in OTHER apps — the most reliable
        // way to detect "clicked outside" with .nonactivatingPanel + .accessory policy,
        // since windowDidResignKey can be unreliable on macOS 15/16.
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.panelWindowDidResignKey() }
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .recallPanelShow, object: nil)
        }
    }

    // Explicit dismiss: Escape, Enter, settings gear — return focus to previous app.
    func dismissPanel() {
        guard panelIsVisible else { return }
        panelIsVisible = false
        removeClickOutsideMonitor()
        panelWindow?.animateOut()
        returnFocusToPreviousApp()
    }

    private func returnFocusToPreviousApp() {
        guard let prev = monitor.lastActiveApp, prev != NSRunningApplication.current else { return }
        prev.activate(options: .activateIgnoringOtherApps)
    }

    private func buildPanel() {
        let view = ClipboardPanelView(
            store: store,
            monitor: monitor,
            panelController: panelController,
            onDismiss: { [weak self] in self?.dismissPanel() },
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        self.panelView = view
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 620, height: 520)
        let window = ClipboardPanelWindow(contentView: host)
        window.panelController = panelController
        panelWindow = window
    }


    // MARK: - Onboarding

    private var onboardingWindow: NSWindow?

    private func showOnboarding() {
        // Switch to .regular so the window stays visible when the user
        // clicks away — accessory-policy apps hide all windows on deactivate.
        NSApp.setActivationPolicy(.regular)

        let view = OnboardingView(settings: settings) { [weak self] in
            guard let self else { return }
            self.settings.hasCompletedOnboarding = true
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
            NSApp.setActivationPolicy(.accessory)
            // Re-register the global hotkey — switching activation policy
            // can invalidate the Carbon event handler registration.
            self.registerHotkey()
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.center()

        // If user closes via red X without finishing, still switch back to accessory.
        let closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            NSApp.setActivationPolicy(.accessory)
            self?.onboardingWindow = nil
        }
        _ = closeObserver   // retained by NotificationCenter

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}

// MARK: - Settings Window Controller

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static var _shared: SettingsWindowController?

    static func shared(store: ClipboardStore, monitor: ClipboardMonitor) -> SettingsWindowController {
        if let existing = _shared { return existing }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Recall Settings"
        window.contentView = NSHostingView(rootView: SettingsView(store: store, monitor: monitor))
        window.center()
        let wc = SettingsWindowController(window: window)
        window.delegate = wc
        _shared = wc
        return wc
    }

    // Destroy singleton when user closes the window so next open gets fresh SwiftUI state
    func windowWillClose(_ notification: Notification) {
        SettingsWindowController._shared = nil
    }
}

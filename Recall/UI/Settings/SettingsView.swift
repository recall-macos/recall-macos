import SwiftUI
import AppKit
import Carbon

// MARK: - Section

enum SettingsSection: String, CaseIterable, Hashable {
    case general, appearance, privacy, keyboard

    var label: String {
        switch self {
        case .general:    "General"
        case .appearance: "Appearance"
        case .privacy:    "Privacy"
        case .keyboard:   "Keyboard"
        }
    }
    var icon: String {
        switch self {
        case .general:    "gear"
        case .appearance: "paintbrush.fill"
        case .privacy:    "lock.shield.fill"
        case .keyboard:   "keyboard.fill"
        }
    }
    var badgeColor: Color {
        switch self {
        case .general:    .blue
        case .appearance: .purple
        case .privacy:    .green
        case .keyboard:   .indigo
        }
    }
}

// MARK: - Root

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject private var settings: AppSettings = .shared

    @State private var selected: SettingsSection = .general
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 800, height: 520)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 13))
                TextField("Search Settings", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Section label
            Text("RECALL")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            // Nav items
            ForEach(filteredSections, id: \.self) { section in
                SidebarItem(section: section, isSelected: selected == section) {
                    selected = section
                }
            }

            Spacer()
        }
        .frame(width: 210)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var filteredSections: [SettingsSection] {
        guard !searchText.isEmpty else { return SettingsSection.allCases }
        return SettingsSection.allCases.filter {
            $0.label.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                switch selected {
                case .general:    GeneralPane(settings: settings, monitor: monitor)
                case .appearance: AppearancePane(settings: settings)
                case .privacy:    PrivacyPane(settings: settings, store: store)
                case .keyboard:   KeyboardPane()
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Sidebar Item

private struct SidebarItem: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(section.badgeColor.gradient)
                        .frame(width: 28, height: 28)
                    Image(systemName: section.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(section.label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Row Components

struct DetailSection: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
}

struct DetailRow<Control: View>: View {
    let label: String
    let subtitle: String?
    @ViewBuilder var control: () -> Control

    init(_ label: String, subtitle: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.label = label
        self.subtitle = subtitle
        self.control = control
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13))
                    if let sub = subtitle {
                        Text(sub)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                control()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)

            Divider().padding(.leading, 28)
        }
    }
}

// MARK: - General Pane

private struct GeneralPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var monitor: ClipboardMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailSection(title: "General")

            DetailRow("Launch at Login",
                      subtitle: "Recall starts automatically when you log in") {
                Toggle("", isOn: $settings.launchAtLogin).labelsHidden()
            }

            DetailRow("Pause Monitoring",
                      subtitle: "Stop recording new clipboard items") {
                Toggle("", isOn: $settings.isMonitoringPaused)
                    .labelsHidden()
                    .onChange(of: settings.isMonitoringPaused) { _, paused in
                        paused ? monitor.stop() : monitor.start()
                    }
            }

            // ADS: uncomment when AdSense is live
            // if !settings.isPro {
            //     SponsorSettingsRow(settings: settings)
            // }

            DetailRow("Show Menu Bar Icon") {
                Toggle("", isOn: $settings.showMenuBarIcon).labelsHidden()
            }

            DetailSection(title: "History")

            DetailRow("History Limit",
                      subtitle: "Maximum number of items to keep") {
                Picker("", selection: $settings.historyLimit) {
                    ForEach(HistoryLimit.allCases, id: \.rawValue) { l in
                        Text(l.displayName).tag(l.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 130)
            }
        }
    }
}

// MARK: - Privacy Pane

private struct PrivacyPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ClipboardStore

    @State private var showClearAlert = false
    @State private var clearAllMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailSection(title: "App Exclusions")
            AppExclusionsRow(settings: settings)

            DetailSection(title: "Sensitive Content")
            DetailRow("Skip Sensitive Items",
                      subtitle: "Passwords, OTPs, and credit card numbers are never saved") {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }

            DetailSection(title: "Screenshots")

            ScreenshotSetupRow()

            DetailSection(title: "Auto-Expire")

            DetailRow("Delete history after",
                      subtitle: "Items older than this are removed automatically") {
                Picker("", selection: $settings.historyExpirationHours) {
                    ForEach(HistoryExpiration.allCases, id: \.rawValue) { e in
                        Text(e.displayName).tag(e.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 130)
            }

            DetailSection(title: "Data")

            DetailRow("Clear Non-Pinned History",
                      subtitle: "Pinned items are kept") {
                Button("Clear…") { clearAllMode = false; showClearAlert = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            DetailRow("Clear All History",
                      subtitle: "Includes pinned items") {
                Button("Clear All…") { clearAllMode = true; showClearAlert = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
            }

            DetailSection(title: "Privacy Assurances")

            DetailRow("Local Storage Only",
                      subtitle: "All data stays on this Mac, never uploaded") {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            DetailRow("No Cloud Sync",
                      subtitle: "Recall does not connect to the internet") {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            DetailRow("No Analytics",
                      subtitle: "Zero tracking or telemetry, ever") {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .alert("Clear History?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button(clearAllMode ? "Clear All" : "Clear Non-Pinned", role: .destructive) {
                if clearAllMode { store.clearEverything() } else { store.clearAll() }
            }
        } message: {
            Text(clearAllMode
                 ? "Permanently deletes all clipboard history including pinned items."
                 : "Deletes all non-pinned clipboard history.")
        }
    }
}

// MARK: - App Exclusions Row

private struct AppExclusionsRow: View {
    @ObservedObject var settings: AppSettings
    @State private var newBundleID = ""
    @State private var showAppPicker = false

    private var excluded: [String] { settings.excludedBundleIDs }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // List of excluded apps
            if excluded.isEmpty {
                HStack {
                    Text("No excluded apps — clipboard is monitored in all apps")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    addButton
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                Divider().padding(.leading, 28)
            } else {
                ForEach(excluded, id: \.self) { bundleID in
                    HStack(spacing: 10) {
                        appIcon(for: bundleID)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(appName(for: bundleID))
                                .font(.system(size: 13))
                            Text(bundleID)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            settings.excludedBundleIDs.removeAll { $0 == bundleID }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    Divider().padding(.leading, 28)
                }
                HStack {
                    Spacer()
                    addButton
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 8)
                Divider().padding(.leading, 28)
            }
        }
        .sheet(isPresented: $showAppPicker) {
            AppPickerSheet(settings: settings)
        }
    }

    private var addButton: some View {
        Button {
            showAppPicker = true
        } label: {
            Label("Add App", systemImage: "plus.circle")
                .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    private func appName(for bundleID: String) -> String {
        // Check running apps first (fast path), then fall back to installed app name
        if let name = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID })?.localizedName {
            return name
        }
        if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path,
           let info = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent("Contents/Info.plist")) as? [String: Any] {
            if let name = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) {
                return name
            }
        }
        return bundleID.components(separatedBy: ".").last?.capitalized ?? bundleID
    }

    private func appIcon(for bundleID: String) -> some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
    }
}

// MARK: - App Picker Sheet

private struct InstalledApp: Identifiable {
    let id: String          // bundle identifier
    let name: String
    let icon: NSImage?
    let bundlePath: String
}

private struct AppPickerSheet: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var allApps: [InstalledApp] = []

    private var filteredApps: [InstalledApp] {
        let available = allApps.filter { !settings.excludedBundleIDs.contains($0.id) }
        guard !searchText.isEmpty else { return available }
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Exclude an App")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField("Search installed apps…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            if allApps.isEmpty {
                Spacer()
                ProgressView("Scanning apps…")
                Spacer()
            } else {
                List(filteredApps) { app in
                    Button {
                        settings.excludedBundleIDs.append(app.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            if let icon = app.icon {
                                Image(nsImage: icon).resizable().frame(width: 28, height: 28)
                            } else {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, height: 28)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name)
                                    .font(.system(size: 13))
                                Text(app.id)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 400, height: 460)
        .task { allApps = await loadInstalledApps() }
    }

    private func loadInstalledApps() async -> [InstalledApp] {
        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let searchDirs = [
                "/Applications",
                "\(NSHomeDirectory())/Applications",
                "/System/Applications",
            ]
            var apps: [InstalledApp] = []
            var seen = Set<String>()

            func scan(_ dir: String) {
                guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { return }
                for entry in contents {
                    let full = (dir as NSString).appendingPathComponent(entry)
                    guard entry.hasSuffix(".app") else {
                        // Recurse one level into subfolders (e.g. /Applications/Utilities)
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue {
                            scan(full)
                        }
                        continue
                    }
                    let plist = (full as NSString).appendingPathComponent("Contents/Info.plist")
                    guard let info = NSDictionary(contentsOfFile: plist) as? [String: Any],
                          let bundleID = info["CFBundleIdentifier"] as? String,
                          !seen.contains(bundleID) else { continue }
                    seen.insert(bundleID)
                    let name = (info["CFBundleDisplayName"] as? String)
                           ?? (info["CFBundleName"] as? String)
                           ?? (entry as NSString).deletingPathExtension
                    let icon = NSWorkspace.shared.icon(forFile: full)
                    apps.append(InstalledApp(id: bundleID, name: name, icon: icon, bundlePath: full))
                }
            }

            for dir in searchDirs { scan(dir) }
            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value
    }
}

// MARK: - Screenshot Setup Row

private struct ScreenshotSetupRow: View {
    @State private var enabled: Bool = ScreenshotCapture.isEnabled

    var body: some View {
        DetailRow(
            "Capture Screenshots",
            subtitle: enabled
                ? "⌘⇧3 / ⌘⇧4 screenshots go directly to your clipboard history"
                : "Enable to redirect screenshots to clipboard so Recall captures them"
        ) {
            Toggle("", isOn: $enabled)
                .labelsHidden()
                .onChange(of: enabled) { _, on in
                    ScreenshotCapture.setEnabled(on)
                }
        }
    }
}

enum ScreenshotCapture {
    static var isEnabled: Bool {
        let ud = UserDefaults(suiteName: "com.apple.screencapture")
        return ud?.string(forKey: "target") == "clipboard"
    }

    static func setEnabled(_ on: Bool) {
        if on {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            proc.arguments = ["write", "com.apple.screencapture", "target", "clipboard"]
            try? proc.run(); proc.waitUntilExit()
        } else {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            proc.arguments = ["delete", "com.apple.screencapture", "target"]
            try? proc.run(); proc.waitUntilExit()
        }
    }
}

// MARK: - Appearance Pane

private struct AppearancePane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailSection(title: "Theme")

            DetailRow("Color Scheme",
                      subtitle: "Controls the look of all Recall windows") {
                Picker("", selection: $settings.colorSchemeRaw) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
                .labelsHidden()
                .onChange(of: settings.colorSchemeRaw) { _, raw in
                    applyAppearance(raw)
                }
                .onAppear { applyAppearance(settings.colorSchemeRaw) }
            }

            DetailSection(title: "Updates")

            UpdateCheckRow()
        }
    }

    private func applyAppearance(_ raw: String) {
        switch raw {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":  NSApp.appearance = NSAppearance(named: .darkAqua)
        default:      NSApp.appearance = nil   // follow system
        }
    }
}

private struct UpdateCheckRow: View {
    @State private var status: UpdateStatus = .idle

    enum UpdateStatus {
        case idle, checking, upToDate, available(String), error
    }

    var body: some View {
        DetailRow("Check for Updates",
                  subtitle: statusSubtitle) {
            Button(action: checkForUpdates) {
                if case .checking = status {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Check Now")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled({ if case .checking = status { return true }; return false }())
        }
    }

    private var statusSubtitle: String {
        switch status {
        case .idle:              return "Latest version: unknown"
        case .checking:          return "Checking GitHub for updates…"
        case .upToDate:          return "You're on the latest version"
        case .available(let v):  return "Version \(v) is available — download from GitHub"
        case .error:             return "Couldn't reach GitHub — check your connection"
        }
    }

    private func checkForUpdates() {
        status = .checking
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let apiURL = URL(string: "https://api.github.com/repos/recall-macos/recall-macos/releases/latest")!
        var req = URLRequest(url: apiURL)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String else {
                    status = .error; return
                }
                let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                status = latest > currentVersion ? .available(latest) : .upToDate
            }
        }.resume()
    }
}

// MARK: - Keyboard Pane

private struct KeyboardPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailSection(title: "Global Shortcut")
            DetailRow("Open Recall",
                      subtitle: "Click to record a new shortcut") {
                ShortcutRecorderButton()
            }

            DetailSection(title: "Panel Navigation")
            DetailRow("Move Selection")       { KeyBadge(keys: ["↑", "↓"]) }
            DetailRow("Jump to First / Last") { KeyBadge(keys: ["↖", "↘"]) }
            DetailRow("Switch Filter Tab")    { KeyBadge(keys: ["⌘", "←", "→"]) }
            DetailRow("Jump to Tab 1–6")      { KeyBadge(keys: ["⌘", "1–6"]) }
            DetailRow("Quick Select Item")    { KeyBadge(keys: ["1–9"]) }
            DetailRow("Focus Search")         { KeyBadge(keys: ["⌘", "F"]) }
            DetailRow("Copy & Paste")         { KeyBadge(keys: ["↵"]) }
            DetailRow("Pin / Unpin")          { KeyBadge(keys: ["⌘", "P"]) }
            DetailRow("Delete Item")          { KeyBadge(keys: ["⌘", "⌫"]) }
            DetailRow("Dismiss")              { KeyBadge(keys: ["⎋"]) }
        }
    }
}

// MARK: - Shortcut Recorder

private struct ShortcutRecorderButton: View {
    @AppStorage("globalShortcutKeyCode") private var keyCode: Int = 9
    @AppStorage("globalShortcutModifiers") private var modifiers: Int = 768

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            Text(isRecording ? "Press shortcut…" : shortcutLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isRecording ? Color.accentColor : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isRecording
                              ? Color.accentColor.opacity(0.10)
                              : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isRecording ? Color.accentColor : Color(nsColor: .separatorColor),
                            lineWidth: isRecording ? 1.5 : 0.5
                        )
                )
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording() }
    }

    private var shortcutLabel: String { carbonShortcutString(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers)) }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            if event.keyCode == 53 { stopRecording(); return nil } // Esc cancels

            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !mods.isEmpty else { return event }

            var newMods: Int = 0
            if mods.contains(.command) { newMods |= Int(cmdKey) }
            if mods.contains(.shift)   { newMods |= Int(shiftKey) }
            if mods.contains(.option)  { newMods |= Int(optionKey) }
            if mods.contains(.control) { newMods |= Int(controlKey) }

            keyCode = Int(event.keyCode)
            modifiers = newMods
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
        isRecording = false
    }
}

private func carbonShortcutString(keyCode: UInt32, modifiers: UInt32) -> String {
    var label = ""
    if modifiers & UInt32(controlKey) != 0 { label += "⌃" }
    if modifiers & UInt32(optionKey)  != 0 { label += "⌥" }
    if modifiers & UInt32(shiftKey)   != 0 { label += "⇧" }
    if modifiers & UInt32(cmdKey)     != 0 { label += "⌘" }
    label += keyCodeSymbol(keyCode)
    return label
}

private func keyCodeSymbol(_ keyCode: UInt32) -> String {
    let map: [UInt32: String] = [
        0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",
        11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",31:"O",32:"U",
        34:"I",35:"P",37:"L",38:"J",40:"K",45:"N",46:"M",
        36:"↵",48:"⇥",49:"Space",51:"⌫",53:"⎋",
        123:"←",124:"→",125:"↓",126:"↑",
    ]
    return map[keyCode] ?? "(\(keyCode))"
}

// MARK: - Sponsor Settings Row

private struct SponsorSettingsRow: View {
    @ObservedObject var settings: AppSettings
    @State private var showLicenseEntry = false
    @State private var licenseKey = ""
    @State private var licenseError = false

    var body: some View {
        VStack(spacing: 0) {
            DetailSection(title: "Ads & Licensing")

            DetailRow("Ad-supported",
                      subtitle: "Recall is free — ads keep it that way") {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }

            DetailRow("Remove Ads",
                      subtitle: "Enter a license key to permanently hide all ads") {
                Button("Enter License…") { showLicenseEntry = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .sheet(isPresented: $showLicenseEntry) {
            licenseSheet
        }
    }

    private var licenseSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)

            Text("Enter License Key")
                .font(.title2.bold())

            Text("Purchase a license key to remove all ads and support ongoing development.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 260)

            if licenseError {
                Text("Invalid license key. Please check and try again.")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button("Cancel") { showLicenseEntry = false }
                    .buttonStyle(.bordered)

                Button("Activate") { activateLicense() }
                    .buttonStyle(.borderedProminent)
                    .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Divider()

            Button("Buy a License →") {
                NSWorkspace.shared.open(
                    URL(string: "https://github.com/recall-macos/recall-macos")!
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .font(.system(size: 12))
        }
        .padding(32)
        .frame(width: 380)
    }

    private func activateLicense() {
        // Simple offline validation — check against a known valid key format.
        // Replace with a real validation call (Gumroad API, Paddle, etc.) when you have one.
        let cleaned = licenseKey.uppercased().trimmingCharacters(in: .whitespaces)
        let pattern = #"^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$"#
        guard cleaned.range(of: pattern, options: .regularExpression) != nil else {
            licenseError = true; return
        }
        // Accepted — mark as pro
        settings.isPro = true
        showLicenseEntry = false
        licenseKey = ""
        licenseError = false
    }
}

// MARK: - Key Badge

private struct KeyBadge: View {
    let keys: [String]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { k in
                Text(k)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }
}

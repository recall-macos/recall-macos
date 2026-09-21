import SwiftUI
import AppKit

// MARK: - Clipboard Panel View

struct ClipboardPanelView: View {
    @ObservedObject var store: ClipboardStore
    let monitor: ClipboardMonitor
    @ObservedObject var panelController: PanelController
    let onDismiss: () -> Void
    let onOpenSettings: () -> Void

    @State private var searchText = ""
    @State private var selectedCategory: FilterCategory = .all
    @FocusState private var searchFocused: Bool
    @State private var quickActionItem: ClipboardItem?
    @State private var showCopiedToast = false

    // Convenience so callers can read the cursor without going through panelController
    private var selectedIndex: Int { panelController.selectedIndex }

    // 0 = closed, 1 = fully open
    @State private var animationProgress: CGFloat = 0

    private var results: [ClipboardItem] {
        SearchEngine.search(query: searchText, in: store.items, category: selectedCategory)
    }

    var body: some View {
        ZStack {
            // Frosted glass body — .regularMaterial blurs the desktop behind the window
            // and renders as a warm gray in light mode rather than stark white.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
            // Subtle depth tint — slightly darker in both modes for visual warmth
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.04))
            // Glass edge highlight
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            VStack(spacing: 0) {
                searchBar
                divider
                filterTabs
                divider
                clipboardList
                bottomBar
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // "Copied" toast
            if showCopiedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.green)
                        Text("Copied")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 54)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            }
        }
        .frame(width: 620, height: 520)
        .shadow(color: .black.opacity(0.30), radius: 40, x: 0, y: 18)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
        // Subtle spring entrance: scale from 0.92→1, opacity 0→1.
        // Do NOT use y < ~0.88 — SwiftUI's HostingScrollView asserts when the
        // inverse of the scale transform is computed (NSCGSizeApplyInverseAffineTransform).
        .scaleEffect(
            x: 0.92 + 0.08 * animationProgress,
            y: 0.92 + 0.08 * animationProgress,
            anchor: .center
        )
        .opacity(Double(animationProgress))
        .onAppear {
            panelController.reset(resultCount: results.count)
            playOpenAnimation()
        }
        // Re-trigger every time the panel is shown. Notification fires after the
        // window is key (see AppDelegate.showPanel), so @FocusState changes land.
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: showCopiedToast)
        .onReceive(NotificationCenter.default.publisher(for: .recallPanelShow)) { _ in
            searchText = ""
            selectedCategory = .all
            quickActionItem = nil
            showCopiedToast = false
            panelController.reset(resultCount: results.count)
            searchFocused = true   // always focus search — typing filters the list
            playOpenAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .recallKeyEvent)) { note in
            guard let raw = note.userInfo?["key"] as? String,
                  let key = RecallKeyEvent(rawValue: raw) else { return }
            // tabDirect carries an index alongside the key
            if key == .tabDirect, let idx = note.userInfo?["tabIndex"] as? Int {
                let all = FilterCategory.allCases
                if idx >= 0, idx < all.count {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedCategory = all[idx] }
                }
                return
            }
            handleKeyEvent(key)
        }
        .onChange(of: results.count) { _, count in
            panelController.updateCount(count)
            // Don't steal focus back to search while user is navigating the list.
            // Only move to search when the list becomes completely empty.
            if count == 0 { searchFocused = true }
        }
        .onChange(of: selectedCategory) { _, _ in
            panelController.reset(resultCount: results.count)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(searchFocused ? Color.accentColor : Color.secondary)
                .animation(.easeInOut(duration: 0.15), value: searchFocused)

            TextField("Search clipboard\u{2026}", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .regular))
                .focused($searchFocused)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.primary.opacity(0.04))
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        FilterTabsView(selected: $selectedCategory)
    }

    // MARK: - List

    private var clipboardList: some View {
        Group {
            if results.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 2) {
                            pinnedSection
                            unpinnedSection
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: selectedIndex) { _, newIdx in
                        guard newIdx < results.count else { return }
                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(results[newIdx].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .overlay {
            if let item = quickActionItem {
                // Capture previousApp NOW (at overlay build time), same as selectCurrentItem()
                let prevApp = monitor.lastActiveApp
                QuickActionsOverlay(
                    item: item,
                    onDismiss: { quickActionItem = nil },
                    onCopy: {
                        quickActionItem = nil
                        store.restoreToPasteboard(item)
                    },
                    onPin: {
                        quickActionItem = nil
                        store.togglePin(item)
                    },
                    onDelete: {
                        quickActionItem = nil
                        withAnimation(.easeOut(duration: 0.18)) {
                            store.remove(item)
                            panelController.clampAfterDelete()
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.78), value: quickActionItem?.id)
    }

    @ViewBuilder
    private var pinnedSection: some View {
        let pinned = results.filter { $0.isPinned }
        if !pinned.isEmpty && (selectedCategory == .all || selectedCategory == .pinned) {
            sectionHeader("Pinned")
            ForEach(Array(pinned.enumerated()), id: \.element.id) { offset, item in
                rowView(item: item, index: offset).id(item.id)
            }
        }
    }

    @ViewBuilder
    private var unpinnedSection: some View {
        let pinned = results.filter { $0.isPinned }
        let unpinned = results.filter { !$0.isPinned }
        if !unpinned.isEmpty && selectedCategory != .pinned {
            if !pinned.isEmpty { sectionHeader("Recent") }
            ForEach(Array(unpinned.enumerated()), id: \.element.id) { offset, item in
                rowView(item: item, index: pinned.count + offset).id(item.id)
            }
        }
    }

    private func rowView(item: ClipboardItem, index: Int) -> some View {
        ClipboardItemRow(
            item: item,
            isSelected: selectedIndex == index,
            onPin: { store.togglePin(item) },
            onDelete: {
                withAnimation(.easeOut(duration: 0.18)) {
                    store.remove(item)
                    panelController.clampAfterDelete()
                }
            }
        )
        .overlay(
            DualClickHandler(
                onLeftClick: {
                    searchFocused = false
                    panelController.jumpTo(index: index)
                    store.restoreToPasteboard(item)
                    showCopiedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        animateDismiss()
                    }
                },
                onRightClick: {
                    searchFocused = false
                    panelController.jumpTo(index: index)
                    // Dismiss any open overlay first, wait for its exit animation,
                    // then re-show for the new item (fixes "second click does nothing" bug).
                    let alreadyOpen = quickActionItem != nil
                    quickActionItem = nil
                    let delay = alreadyOpen ? 0.22 : 0.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        quickActionItem = item
                    }
                }
            )
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.8)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "No clipboard history yet" : "No results for \"\(searchText)\"")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Ad / promo strip
            adStrip
            Divider().opacity(0.3)
            // Keyboard hints + settings gear
            HStack(spacing: 16) {
                keyHint("↑↓", label: "Navigate")
                keyHint("↵", label: "Paste")
                keyHint("⌘←→", label: "Filter")
                keyHint("⌘P", label: "Pin")
                keyHint("⌘⌫", label: "Delete")
                Spacer()
                Button {
                    onDismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onOpenSettings() }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(.thinMaterial)
    }

    // ADS: uncomment SponsorBanner() below when AdSense is set up.
    // 1. Add publisher ID + slot ID to docs/ad.html
    // 2. Enable GitHub Pages on the repo (docs/ folder)
    // 3. Uncomment the line below and rebuild
    @ViewBuilder
    private var adStrip: some View {
        // if !AppSettings.shared.isPro {
        //     SponsorBanner()
        // }
        EmptyView()
    }

    private func keyHint(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private var divider: some View {
        Divider().opacity(0.5)
    }

    // MARK: - Key handling

    private func handleKeyEvent(_ key: RecallKeyEvent) {
        switch key {
        case .arrowUp, .arrowDown: break  // handled by PanelController via sendEvent
        case .enter:      selectCurrentItem()
        case .cmdDelete:  deleteCurrentItem()
        case .cmdP:       pinCurrentItem()
        case .cmdF:
            searchFocused = true
        case .tabNext:
            let all = FilterCategory.allCases
            if let idx = all.firstIndex(of: selectedCategory) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedCategory = all[(idx + 1) % all.count]
                }
            }
        case .tabPrev:
            let all = FilterCategory.allCases
            if let idx = all.firstIndex(of: selectedCategory) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedCategory = all[(idx - 1 + all.count) % all.count]
                }
            }
        default:
            // Digit quick-select: only jump when search is empty so typed digits
            // still search normally when the user is filtering.
            if let idx = key.digitIndex, searchText.isEmpty {
                panelController.jumpTo(index: idx)
            } else if let idx = key.digitIndex {
                // Search is active — append digit to search text
                searchText += key.rawValue.replacingOccurrences(of: "digit", with: "")
            }
        }
    }

    private func selectCurrentItem() {
        guard selectedIndex >= 0, selectedIndex < results.count else { return }
        let item = results[selectedIndex]
        let previousApp = monitor.lastActiveApp
        // Paste immediately (inside the keypress user-interaction window),
        // then dismiss in parallel — Cmd+V fires at +0.30s after activation.
        PasteEngine.shared.paste(item, into: previousApp, store: store)
        animateDismiss()
    }

    private func deleteCurrentItem() {
        guard selectedIndex >= 0, selectedIndex < results.count else { return }
        let item = results[selectedIndex]
        withAnimation(.easeOut(duration: 0.18)) {
            store.remove(item)
            panelController.clampAfterDelete()
        }
    }

    private func pinCurrentItem() {
        guard selectedIndex >= 0, selectedIndex < results.count else { return }
        store.togglePin(results[selectedIndex])
    }

    // MARK: - Animation helpers

    private func playOpenAnimation() {
        animationProgress = 0
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72, blendDuration: 0)) {
            animationProgress = 1
        }
    }

    func animateDismiss(completion: (() -> Void)? = nil) {
        withAnimation(.easeIn(duration: 0.12)) {
            animationProgress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            onDismiss()
            completion?()
        }
    }
}

// MARK: - Quick Actions Overlay

private struct QuickActionsOverlay: View {
    let item: ClipboardItem
    let onDismiss: () -> Void
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Preview header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(iconBg)
                            .frame(width: 32, height: 32)
                        Image(systemName: item.contentType.sfSymbol)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(iconFg)
                    }
                    Text(previewText)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                Divider().opacity(0.4)

                ActionRow(icon: "doc.on.doc", label: "Copy", tint: .accentColor, action: onCopy)

                if item.contentType == .url, let text = item.textContent, let url = URL(string: text) {
                    ActionRow(icon: "safari", label: "Open URL") {
                        onDismiss(); NSWorkspace.shared.open(url)
                    }
                }
                if item.contentType == .file, let path = item.filePaths?.first {
                    ActionRow(icon: "folder", label: "Reveal in Finder") {
                        onDismiss()
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                }

                Divider().opacity(0.4)
                ActionRow(icon: item.isPinned ? "pin.slash" : "pin",
                          label: item.isPinned ? "Unpin" : "Pin", action: onPin)
                Divider().opacity(0.4)
                ActionRow(icon: "trash", label: "Delete", tint: .red, action: onDelete)
            }
            .frame(width: 260)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                ))
            .shadow(color: .black.opacity(0.28), radius: 28, x: 0, y: 10)
        }
        .ignoresSafeArea()
    }

    private var previewText: String {
        switch item.contentType {
        case .image: return "Image"
        case .file: return item.filePaths?.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File"
        default: return item.preview
        }
    }
    private var iconBg: Color {
        switch item.contentType {
        case .url: return .blue.opacity(0.12)
        case .email: return .indigo.opacity(0.12)
        case .code: return .orange.opacity(0.12)
        default: return Color.primary.opacity(0.07)
        }
    }
    private var iconFg: Color {
        switch item.contentType {
        case .url: return .blue
        case .email: return .indigo
        case .code: return .orange
        default: return .secondary
        }
    }
}

// Individual action row with hover highlight
private struct ActionRow: View {
    let icon: String
    let label: String
    var tint: Color = .primary
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint == .primary ? Color.secondary : tint)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13, weight: hovered ? .medium : .regular))
                    .foregroundStyle(tint == .primary ? Color.primary : tint)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(hovered ? Color.primary.opacity(0.07) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: hovered)
    }
}

// MARK: - Dual click detector (left = copy, right = actions menu)
// Using NSViewRepresentable for BOTH clicks avoids the SwiftUI overlay eating
// left-click events before onTapGesture sees them.

struct DualClickHandler: NSViewRepresentable {
    let onLeftClick: () -> Void
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> DCView { DCView(onLeft: onLeftClick, onRight: onRightClick) }
    func updateNSView(_ v: DCView, context: Context) { v.onLeft = onLeftClick; v.onRight = onRightClick }

    class DCView: NSView {
        var onLeft: () -> Void
        var onRight: () -> Void

        init(onLeft: @escaping () -> Void, onRight: @escaping () -> Void) {
            self.onLeft = onLeft; self.onRight = onRight
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func mouseDown(with event: NSEvent) { onLeft() }
        override func rightMouseDown(with event: NSEvent) { onRight() }
    }
}


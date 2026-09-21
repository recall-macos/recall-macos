import Foundation
import Combine

// MARK: - Clipboard Store

/// Central in-memory store for clipboard history.
/// Acts as the single source of truth — UI binds to this, persistence reads/writes from it.
@MainActor
final class ClipboardStore: ObservableObject {

    @Published private(set) var items: [ClipboardItem] = []

    private let settings: AppSettings
    private let storage: ClipboardStorage

    init(settings: AppSettings = .shared) {
        self.settings = settings
        self.storage = ClipboardStorage()
        // Load then reclassify any richText items where the content is actually
        // a URL, email, or code — fixes items stored before detection was added.
        self.items = ClipboardStore.reclassify(storage.load())
    }

    private static func reclassify(_ items: [ClipboardItem]) -> [ClipboardItem] {
        items.map { item in
            guard item.contentType == .richText || item.contentType == .text,
                  let text = item.textContent else { return item }
            let detected = ContentTypeDetector.detect(text)
            guard detected != .text else { return item }
            var updated = item
            updated.contentType = detected
            return updated
        }
    }

    // MARK: - Mutations

    func add(_ item: ClipboardItem) {
        // Dedup: if same content is already the most recent item, skip
        if let first = items.first, first.hasSameContent(as: item) { return }

        // Remove older duplicates
        items.removeAll { $0.hasSameContent(as: item) && !$0.isPinned }

        items.insert(item, at: 0)
        enforceLimit()
        persist()
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persistNow()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isPinned.toggle()
        persistNow()
    }

    func clearAll() {
        items.removeAll { !$0.isPinned }
        persistNow()
    }

    func clearEverything() {
        items.removeAll()
        persistNow()
    }

    // MARK: - Expiration

    func pruneExpired() {
        let hours = settings.historyExpirationHours
        guard hours > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        items.removeAll { !$0.isPinned && $0.timestamp < cutoff }
        persist()
    }

    // MARK: - Private

    private func enforceLimit() {
        let limit = settings.historyLimit
        guard limit > 0 else { return }

        // Pinned items never count toward the limit
        var unpinned = items.filter { !$0.isPinned }
        let pinned = items.filter { $0.isPinned }

        if unpinned.count > limit {
            unpinned = Array(unpinned.prefix(limit))
        }

        // Maintain insertion order: pinned items stay at their position
        // Simplest: pinned float to top, then recent unpinned
        items = pinned + unpinned
    }

    /// Called on app termination to flush any pending debounced save.
    func flushPendingSave() {
        storage.saveNow(items)
    }

    private func persist() {
        storage.saveNow(items)   // immediate — ensures history survives process kill
    }

    private func persistNow() {
        storage.saveNow(items)   // immediate — for pin/delete/clear
    }
}

// MARK: - Clipboard Store + Restore to Pasteboard

import AppKit

extension ClipboardStore {
    /// Write item back to NSPasteboard so the user can paste it
    func restoreToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.contentType {
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
        case .file:
            if let paths = item.filePaths {
                let urls = paths.map { URL(fileURLWithPath: $0) } as [NSURL]
                pb.writeObjects(urls)
            }
        default:
            if let text = item.textContent {
                pb.setString(text, forType: .string)
            }
        }
    }
}

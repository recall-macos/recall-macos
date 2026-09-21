import Foundation

// MARK: - Clipboard Storage

/// Persists clipboard history to a JSON file in Application Support.
/// Runs save on a background queue to avoid any main-thread I/O.
final class ClipboardStorage {

    private let fileURL: URL
    private let saveQueue = DispatchQueue(label: "com.recall.storage", qos: .utility)
    private var pendingSave: DispatchWorkItem?

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("Recall", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
    }

    // MARK: - Load

    func load() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            return try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            print("⚠️ ClipboardStorage: Failed to decode history — \(error)")
            return []
        }
    }

    // MARK: - Save

    /// Immediate save — use for pin/delete/clear where losing data would be noticeable.
    func saveNow(_ items: [ClipboardItem]) {
        pendingSave?.cancel()
        write(items)
    }

    /// Debounced save — use for rapid clipboard additions to avoid thrashing disk.
    func save(_ items: [ClipboardItem]) {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.write(items)
        }
        pendingSave = work
        saveQueue.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func write(_ items: [ClipboardItem]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("⚠️ ClipboardStorage: Failed to save — \(error)")
        }
    }
}

import AppKit
import Foundation

final class ScreenshotWatcher {

    private let store: ClipboardStore
    private let monitor: ClipboardMonitor
    private var timer: DispatchSourceTimer?
    private var knownFiles: Set<String> = []
    private let queue = DispatchQueue(label: "com.recall.screenshotwatcher", qos: .utility)

    private static var desktopURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }

    init(store: ClipboardStore, monitor: ClipboardMonitor) {
        self.store = store
        self.monitor = monitor
    }

    func start() {
        stop()
        knownFiles = currentFiles()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.5, repeating: 0.5)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
        knownFiles = []
    }

    private func poll() {
        let current = currentFiles()
        let new = current.subtracting(knownFiles)
        knownFiles = current
        for filename in new where isScreenshot(filename) {
            let url = Self.desktopURL.appendingPathComponent(filename)
            queue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.ingest(url)
            }
        }
    }

    private func currentFiles() -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: Self.desktopURL.path)) ?? [])
    }

    private func isScreenshot(_ name: String) -> Bool {
        let lower = name.lowercased()
        guard lower.hasSuffix(".png") else { return false }
        return lower.hasPrefix("screenshot ") || lower.hasPrefix("screen shot ")
    }

    private func ingest(_ url: URL) {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return }
        let item = ClipboardItem.makeImage(data)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.store.add(item)
            // Tell monitor to skip the next pasteboard change so it doesn't add a duplicate
            self.monitor.suppressNextChange()
            if let image = NSImage(data: data) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([image])
            }
        }
    }
}

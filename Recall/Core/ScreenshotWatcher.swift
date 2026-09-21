import AppKit
import Foundation

// Watches ~/Desktop (and ~/Pictures/Screenshots if it exists) for new macOS screenshots
// and adds them to Recall's clipboard history without redirecting screenshots away from Desktop.
final class ScreenshotWatcher {

    private let store: ClipboardStore
    private var watchers: [(source: DispatchSourceFileSystemObject, fd: Int32)] = []
    private var knownFiles: [String: Set<String>] = [:]  // dir.path -> filenames
    private let queue = DispatchQueue(label: "com.recall.screenshotwatcher", qos: .utility)

    private static var watchedDirs: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Pictures/Screenshots")
        ]
        return candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    init(store: ClipboardStore) {
        self.store = store
    }

    func start() {
        stop()
        for dir in Self.watchedDirs {
            watchDirectory(dir)
        }
    }

    func stop() {
        for w in watchers { w.source.cancel() }
        watchers = []
        knownFiles = [:]
    }

    private func watchDirectory(_ dir: URL) {
        let existing = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)).map(Set.init) ?? []
        knownFiles[dir.path] = existing

        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: queue)
        src.setEventHandler { [weak self] in self?.checkForNew(in: dir) }
        src.setCancelHandler { close(fd) }
        src.resume()
        watchers.append((source: src, fd: fd))
    }

    private func checkForNew(in dir: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        let current = Set(contents)
        let known = knownFiles[dir.path] ?? []
        let newFiles = current.subtracting(known)
        knownFiles[dir.path] = current

        for filename in newFiles where isScreenshot(filename) {
            let url = dir.appendingPathComponent(filename)
            queue.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.ingest(url)
            }
        }
    }

    private func isScreenshot(_ name: String) -> Bool {
        let lower = name.lowercased()
        guard lower.hasSuffix(".png") else { return false }
        // "Screenshot YYYY-MM-DD at HH.MM.SS.png" (macOS Ventura+)
        // "Screen Shot YYYY-MM-DD at HH.MM.SS AM.png" (older)
        return lower.hasPrefix("screenshot ") || lower.hasPrefix("screen shot ")
    }

    private func ingest(_ url: URL) {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return }
        let item = ClipboardItem.makeImage(data)
        DispatchQueue.main.async { [weak self] in
            self?.store.add(item)
        }
    }
}

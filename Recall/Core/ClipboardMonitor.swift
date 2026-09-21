import AppKit
import Combine
import RegexBuilder

// MARK: - Clipboard Monitor

/// Polls NSPasteboard every 0.5s and publishes new items when change is detected.
/// Runs entirely on a background DispatchQueue to avoid main thread blocking.
final class ClipboardMonitor: ObservableObject {

    // Published so any UI can react to monitoring state
    @Published private(set) var isMonitoring: Bool = false

    private let store: ClipboardStore
    private let settings: AppSettings
    private var timer: DispatchSourceTimer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let queue = DispatchQueue(label: "com.recall.clipboard.monitor", qos: .utility)


    // Front-most app at the moment the panel is about to open (used for smart paste)
    private(set) var lastActiveApp: NSRunningApplication?
    private var suppressCount = 0

    func suppressNextChange() {
        queue.async { self.suppressCount += 1 }
    }

    init(store: ClipboardStore, settings: AppSettings = .shared) {
        self.store = store
        self.settings = settings
    }

    // MARK: - Control

    func start() {
        guard !isMonitoring else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        scheduleTimer()
        DispatchQueue.main.async { self.isMonitoring = true }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        DispatchQueue.main.async { self.isMonitoring = false }
    }

    func captureActiveApp() {
        lastActiveApp = NSWorkspace.shared.frontmostApplication
    }

    // MARK: - Timer

    private func scheduleTimer() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.5, repeating: 0.5, leeway: .milliseconds(50))
        t.setEventHandler { [weak self] in
            self?.checkPasteboard()
        }
        t.resume()
        timer = t
    }

    // MARK: - Pasteboard Check

    private func checkPasteboard() {
        guard !settings.isMonitoringPaused else { return }

        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        if suppressCount > 0 { suppressCount -= 1; return }

        // Skip apps the user has explicitly excluded.
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontApp.bundleIdentifier,
           settings.excludedBundleIDs.contains(bundleID) { return }

        if let item = extractItem(from: pasteboard), !SensitiveContentFilter.isSensitive(item) {
            DispatchQueue.main.async { [weak self] in
                self?.store.add(item)
            }
        }
    }

    // MARK: - Extraction

    private static let pngType  = NSPasteboard.PasteboardType("public.png")
    private static let maxImageBytes = 8 * 1024 * 1024  // 8 MB stored cap

    private static let publicURLType = NSPasteboard.PasteboardType("public.url")

    private func extractItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        // 1. Images first — screenshots arrive with a file-URL promise alongside
        //    image data, so images must be checked before files.
        if let data = extractImageData(from: pasteboard) {
            return ClipboardItem.makeImage(data)
        }

        // 2. Dedicated public.url type — the most reliable URL signal.
        //    Browsers (Safari, Chrome) write this when you copy from the address bar
        //    or right-click → Copy Link. Read it as a string directly; readObjects
        //    can miss it on macOS 15 depending on pasteboard conformance.
        if let raw = pasteboard.string(forType: Self.publicURLType) {
            let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty, let url = URL(string: s),
               ["http","https","ftp"].contains(url.scheme ?? "") {
                return ClipboardItem.makeText(s)   // makeText classifies as .url
            }
        }

        // 3. Plain text — checked BEFORE rich text so that a URL (or email/code)
        //    copied alongside RTF is classified by its content, not by the fact
        //    that it has formatting.  Only return early when content type is specific;
        //    generic plain text falls through so we can capture RTF below.
        if let text = pasteboard.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let detected = ContentTypeDetector.detect(trimmed)
                if detected != .text {
                    return ClipboardItem.makeText(trimmed)
                }
            }
        }

        // 4. File URLs (Finder copies, drag-and-drop, etc.)
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self],
                                                  options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !fileURLs.isEmpty {
            return ClipboardItem.makeFiles(fileURLs.map { $0.path })
        }

        // 5. Rich text — only when the pasteboard declares RTF/RTFD types.
        //    NSAttributedString.readObjects(_:) silently wraps plain text in an
        //    NSAttributedString, so we must gate on the declared types first.
        let hasRTF = pasteboard.types?.contains(where: {
            $0 == .rtf || $0 == .rtfd ||
            $0.rawValue == "public.rtf" ||
            $0.rawValue.hasSuffix(".rtfd") ||
            $0.rawValue == "com.apple.flat-rtfd"
        }) ?? false
        if hasRTF,
           let attrString = pasteboard.readObjects(forClasses: [NSAttributedString.self],
                                                    options: nil)?.first as? NSAttributedString {
            let plain = attrString.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !plain.isEmpty else { return nil }
            var item = ClipboardItem.makeText(plain)
            if item.contentType == .text { item.contentType = .richText }
            return item
        }

        // 6. Plain text fallback (no RTF available).
        if let text = pasteboard.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return ClipboardItem.makeText(trimmed)
        }

        return nil
    }

    private func extractImageData(from pasteboard: NSPasteboard) -> Data? {
        // Read PNG bytes directly — avoids the expensive TIFF→NSBitmapImageRep→PNG
        // roundtrip that fails or exhausts memory on large Retina screenshots.
        if let data = pasteboard.data(forType: Self.pngType), !data.isEmpty {
            return cappedImageData(data)
        }
        // TIFF fallback
        if let tiff = pasteboard.data(forType: .tiff), !tiff.isEmpty,
           let image = NSImage(data: tiff), let png = image.pngData {
            return cappedImageData(png)
        }
        // Generic NSImage fallback (covers other image formats)
        if let image = NSImage(pasteboard: pasteboard), let png = image.pngData {
            return cappedImageData(png)
        }
        return nil
    }

    // If the image is over the size cap, store a downscaled thumbnail instead.
    private func cappedImageData(_ data: Data) -> Data? {
        guard data.count > Self.maxImageBytes else { return data }
        guard let image = NSImage(data: data) else { return nil }
        let scale = sqrt(Double(Self.maxImageBytes) / Double(data.count))
        let thumbSize = NSSize(width: image.size.width * scale,
                               height: image.size.height * scale)
        return image.thumbnail(size: thumbSize).pngData
    }
}

// MARK: - Sensitive Content Filter

enum SensitiveContentFilter {
    /// Returns true if the item looks like it contains sensitive data that
    /// should not be saved to clipboard history.
    static func isSensitive(_ item: ClipboardItem) -> Bool {
        guard let text = item.textContent else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // OTP: 4–8 standalone digits (covers 4-digit PINs and 6/8-digit OTPs)
        if trimmed.count >= 4, trimmed.count <= 8,
           trimmed.allSatisfy({ $0.isNumber }) { return true }

        // Credit card: 13–19 digits possibly separated by spaces or dashes
        // Only flag when formatted (has separators) to avoid false positives
        let digitsOnly = trimmed.filter { $0.isNumber }
        let hasSeparators = trimmed.contains(" ") || trimmed.contains("-")
        if digitsOnly.count >= 13, digitsOnly.count <= 19, hasSeparators,
           trimmed.count <= 24, isLuhnValid(digitsOnly) { return true }

        // Common secret-marker prefixes (password managers, env files)
        let lower = trimmed.lowercased()
        let secretPrefixes = ["secret:", "password:", "passwd:", "token:", "api_key=",
                               "apikey=", "bearer ", "private_key:", "secret_key:"]
        if secretPrefixes.contains(where: { lower.hasPrefix($0) }) { return true }

        return false
    }

    private static func isLuhnValid(_ digits: String) -> Bool {
        var sum = 0
        let reversed = digits.reversed()
        for (i, ch) in reversed.enumerated() {
            guard let d = ch.wholeNumberValue else { return false }
            if i % 2 == 1 {
                let doubled = d * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += d
            }
        }
        return sum % 10 == 0
    }
}

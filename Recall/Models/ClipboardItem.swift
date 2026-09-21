import Foundation
import AppKit

// MARK: - Content Type

enum ClipboardContentType: String, Codable, CaseIterable {
    case text
    case url
    case email
    case phoneNumber
    case code
    case image
    case file
    case richText
    case unknown

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .url: return "Link"
        case .email: return "Email"
        case .phoneNumber: return "Phone"
        case .code: return "Code"
        case .image: return "Image"
        case .file: return "File"
        case .richText: return "Rich Text"
        case .unknown: return "Other"
        }
    }

    var sfSymbol: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        case .email: return "envelope"
        case .phoneNumber: return "phone"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .file: return "doc"
        case .richText: return "doc.richtext"
        case .unknown: return "questionmark.square"
        }
    }

    // Filter tab grouping
    var filterCategory: FilterCategory {
        switch self {
        case .text, .richText, .email, .phoneNumber, .code, .unknown: return .text
        case .url: return .links
        case .image: return .images
        case .file: return .files
        }
    }
}

// MARK: - Filter Category

enum FilterCategory: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case links = "Links"
    case images = "Images"
    case files = "Files"
    case pinned = "Pinned"

    var sfSymbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "doc.text"
        case .links: return "link"
        case .images: return "photo"
        case .files: return "folder"
        case .pinned: return "pin"
        }
    }
}

// MARK: - Clipboard Item

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    var contentType: ClipboardContentType
    var timestamp: Date
    var isPinned: Bool

    // Content storage
    var textContent: String?
    var imageData: Data?
    var filePaths: [String]?

    // Computed display helpers
    var preview: String {
        switch contentType {
        case .image:
            return "Image"
        case .file:
            return filePaths?.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File"
        default:
            let raw = textContent ?? ""
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 200 {
                return String(trimmed.prefix(200)) + "…"
            }
            return trimmed
        }
    }

    var displayDomain: String? {
        guard contentType == .url,
              let text = textContent,
              let url = URL(string: text),
              let host = url.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    // Equatable based on content, not id (for dedup)
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    func hasSameContent(as other: ClipboardItem) -> Bool {
        if contentType != other.contentType { return false }
        if let t1 = textContent, let t2 = other.textContent { return t1 == t2 }
        if let i1 = imageData, let i2 = other.imageData { return i1 == i2 }
        if let f1 = filePaths, let f2 = other.filePaths { return f1 == f2 }
        return false
    }
}

// MARK: - Factory

extension ClipboardItem {
    static func makeText(_ text: String) -> ClipboardItem {
        let type = ContentTypeDetector.detect(text)
        return ClipboardItem(
            id: UUID(),
            contentType: type,
            timestamp: Date(),
            isPinned: false,
            textContent: text
        )
    }

    static func makeImage(_ data: Data) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            contentType: .image,
            timestamp: Date(),
            isPinned: false,
            imageData: data
        )
    }

    static func makeFiles(_ paths: [String]) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            contentType: .file,
            timestamp: Date(),
            isPinned: false,
            filePaths: paths
        )
    }
}

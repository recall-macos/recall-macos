import Foundation

// MARK: - Search Engine

struct SearchEngine {
    static func search(query: String, in items: [ClipboardItem], category: FilterCategory) -> [ClipboardItem] {
        var filtered = applyCategory(category, to: items)
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return filtered }
        filtered = applyQuery(query, to: filtered)
        return filtered
    }

    // MARK: - Category filter

    private static func applyCategory(_ category: FilterCategory, to items: [ClipboardItem]) -> [ClipboardItem] {
        switch category {
        case .all: return items
        case .pinned: return items.filter { $0.isPinned }
        case .text: return items.filter { $0.contentType.filterCategory == .text }
        case .links: return items.filter { $0.contentType == .url }
        case .images: return items.filter { $0.contentType == .image }
        case .files: return items.filter { $0.contentType == .file }
        }
    }

    // MARK: - Text search

    private static func applyQuery(_ query: String, to items: [ClipboardItem]) -> [ClipboardItem] {
        let lower = query.lowercased()
        return items.filter { item in
            // Search in text content
            if let text = item.textContent, text.lowercased().contains(lower) { return true }
            // Search in file names
            if let paths = item.filePaths {
                let names = paths.map { URL(fileURLWithPath: $0).lastPathComponent.lowercased() }
                if names.contains(where: { $0.contains(lower) }) { return true }
            }
            return false
        }
    }
}

import Foundation

// MARK: - Content Type Detection

enum ContentTypeDetector {
    static func detect(_ text: String) -> ClipboardContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }

        // Single-line checks first (order matters — more specific before general)
        if isURL(trimmed)         { return .url }
        if isEmail(trimmed)       { return .email }
        if isPhoneNumber(trimmed) { return .phoneNumber }
        if isFilePath(trimmed)    { return .file }

        // Multi-line / structured content
        if isCode(trimmed)        { return .code }
        if isJSON(trimmed)        { return .code }

        return .text
    }

    // MARK: - Detectors

    private static func isURL(_ text: String) -> Bool {
        // Must be a single token with no whitespace
        guard !text.contains(" "), !text.contains("\n") else { return false }
        guard let url = URL(string: text), url.scheme != nil, url.host != nil else { return false }
        return ["http", "https", "ftp", "ftps"].contains(url.scheme ?? "")
    }

    private static func isEmail(_ text: String) -> Bool {
        guard !text.contains(" "), !text.contains("\n") else { return false }
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isPhoneNumber(_ text: String) -> Bool {
        guard !text.contains("\n") else { return false }
        let stripped = text.components(separatedBy: CharacterSet(charactersIn: "0123456789+()-. ").inverted).joined()
        guard stripped.count >= 10 else { return false }
        let pattern = #"^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isFilePath(_ text: String) -> Bool {
        guard !text.contains("\n"), text.count < 1024 else { return false }
        // Absolute paths or tilde-expanded
        let looks = text.hasPrefix("/") || text.hasPrefix("~/") || text.hasPrefix("file://")
        guard looks else { return false }
        // Must have at least one path separator beyond the root
        let stripped = text.hasPrefix("file://") ? String(text.dropFirst(7)) : text
        return stripped.filter { $0 == "/" }.count >= 2
    }

    private static func isCode(_ text: String) -> Bool {
        let codeIndicators = [
            "func ", "class ", "struct ", "import ", "let ", "var ",
            "def ", "return ", "if (", "for (", "while (",
            "<?php", "#!/", "<html", "SELECT ", "FROM ", "WHERE ",
            "const ", "function ", "=>", "->", "::", "&&", "||",
            "public ", "private ", "protected ", "static ", "override ",
            "async ", "await ", "throw ", "catch ", "guard ",
        ]
        let lines = text.components(separatedBy: "\n")
        if lines.count > 2 {
            return codeIndicators.contains { text.contains($0) }
        }
        // Single-line: require 2+ indicators to avoid false positives on prose.
        let matchCount = codeIndicators.filter { text.contains($0) }.count
        return matchCount >= 2
    }

    private static func isJSON(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (t.hasPrefix("{") && t.hasSuffix("}")) ||
              (t.hasPrefix("[") && t.hasSuffix("]")) else { return false }
        guard let data = t.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}

// MARK: - String Helpers

extension String {
    var isMultiline: Bool {
        contains("\n")
    }

    var wordCount: Int {
        components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}

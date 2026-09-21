import SwiftUI
import AppKit

// MARK: - Clipboard Item Row

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onPin: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Type icon / image thumbnail
            itemIcon

            // Main content
            VStack(alignment: .leading, spacing: 2) {
                primaryLabel
                secondaryLabel
            }

            Spacer(minLength: 8)

            // Right-side info: timestamp + pin badge
            VStack(alignment: .trailing, spacing: 4) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(item.timestamp.relativeString)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    // MARK: - Icon

    @ViewBuilder
    private var itemIcon: some View {
        Group {
            if item.contentType == .image, let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else if item.contentType == .file, let path = item.filePaths?.first {
                fileIcon(for: path)
            } else {
                typeIcon
            }
        }
    }

    private var typeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(iconBackground)
                .frame(width: 36, height: 36)
            Image(systemName: item.contentType.sfSymbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconForeground)
        }
    }

    private func fileIcon(for path: String) -> some View {
        let icon = NSWorkspace.shared.icon(forFile: path)
        return Image(nsImage: icon)
            .resizable()
            .frame(width: 36, height: 36)
    }

    // MARK: - Labels

    @ViewBuilder
    private var primaryLabel: some View {
        switch item.contentType {
        case .url:
            HStack(spacing: 4) {
                if let domain = item.displayDomain {
                    Text(domain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
        case .image:
            Text("Image")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        case .file:
            Text(item.filePaths?.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        default:
            Text(item.preview)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var secondaryLabel: some View {
        switch item.contentType {
        case .url:
            if let text = item.textContent {
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        case .file:
            if let path = item.filePaths?.first {
                let ext = URL(fileURLWithPath: path).pathExtension.uppercased()
                Text(ext.isEmpty ? "File" : ext + " File")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Copy") { copyAgain() }

        if item.contentType == .url, let text = item.textContent, let url = URL(string: text) {
            Button("Open URL") { NSWorkspace.shared.open(url) }
        }

        if item.contentType == .file, let path = item.filePaths?.first {
            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            }
        }

        Divider()
        Button(item.isPinned ? "Unpin" : "Pin") { onPin() }
        Divider()
        Button("Delete", role: .destructive) { onDelete() }
    }

    private func copyAgain() {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.contentType {
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) { pb.writeObjects([image]) }
        case .file:
            if let paths = item.filePaths {
                pb.writeObjects(paths.map { URL(fileURLWithPath: $0) } as [NSURL])
            }
        default:
            if let text = item.textContent { pb.setString(text, forType: .string) }
        }
    }

    // MARK: - Styling

    private var rowBackground: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 0.5)
                    )
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            } else {
                Color.clear
            }
        }
    }

    private var iconBackground: Color {
        switch item.contentType {
        case .url: return .blue.opacity(0.12)
        case .email: return .indigo.opacity(0.12)
        case .phoneNumber: return .green.opacity(0.12)
        case .code: return .orange.opacity(0.12)
        case .richText: return .purple.opacity(0.12)
        default: return Color.primary.opacity(0.07)
        }
    }

    private var iconForeground: Color {
        switch item.contentType {
        case .url: return .blue
        case .email: return .indigo
        case .phoneNumber: return .green
        case .code: return .orange
        case .richText: return .purple
        default: return .secondary
        }
    }
}

// MARK: - Date helpers

extension Date {
    var relativeString: String {
        let seconds = -timeIntervalSinceNow
        if seconds < 60 { return "just now" }
        if seconds < 3600 {
            let m = Int(seconds / 60)
            return "\(m)m"
        }
        if seconds < 86400 {
            let h = Int(seconds / 3600)
            return "\(h)h"
        }
        let d = Int(seconds / 86400)
        return "\(d)d"
    }
}

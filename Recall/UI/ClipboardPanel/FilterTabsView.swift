import SwiftUI

// MARK: - Filter Tabs

struct FilterTabsView: View {
    @Binding var selected: FilterCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(FilterCategory.allCases, id: \.self) { category in
                    FilterChip(category: category, isSelected: selected == category) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selected = category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 34)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let category: FilterCategory
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: 10, weight: .medium))
                Text(category.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    @ViewBuilder
    private var chipBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                )
        } else if isHovered {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        } else {
            Color.clear
        }
    }
}

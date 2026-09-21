import Foundation

// Owns the selection cursor for the panel list.
// Lives as a reference type so AppDelegate and ClipboardPanelView
// share one instance — @ObservedObject in the view guarantees
// SwiftUI re-renders whenever selectedIndex changes.

@MainActor
final class PanelController: ObservableObject {
    @Published private(set) var selectedIndex: Int = 0

    // Kept in sync by the view via updateCount(_:) so moveDown can clamp.
    private(set) var resultCount: Int = 0

    func updateCount(_ count: Int) {
        resultCount = count
        if selectedIndex >= count { selectedIndex = max(0, count - 1) }
    }

    func reset(resultCount count: Int) {
        resultCount = count
        selectedIndex = 0
    }

    func moveUp() {
        guard selectedIndex > 0 else { return }
        selectedIndex -= 1
    }

    func moveDown() {
        guard resultCount > 0 else { return }
        selectedIndex = min(resultCount - 1, selectedIndex + 1)
    }

    func jumpTo(index: Int) {
        guard index >= 0, resultCount == 0 || index < resultCount else { return }
        selectedIndex = index
    }

    func jumpToFirst() {
        guard resultCount > 0 else { return }
        selectedIndex = 0
    }

    func jumpToLast() {
        guard resultCount > 0 else { return }
        selectedIndex = resultCount - 1
    }

    func clampAfterDelete() {
        if resultCount > 0 {
            selectedIndex = max(0, min(resultCount - 2, selectedIndex))
        }
    }
}

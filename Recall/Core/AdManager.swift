import Foundation
import AppKit

// MARK: - Ad Model

struct SponsorAd: Codable, Equatable {
    let id: String
    let headline: String        // e.g. "Supercharge your workflow"
    let body: String            // e.g. "Try Raycast — the productivity launcher"
    let cta: String             // e.g. "Get it free"
    let url: String
    let logoURL: String?        // optional remote image URL
    let accentColor: String?    // hex, e.g. "#FF6B35"
}

// MARK: - Ad Manager

@MainActor
final class AdManager: ObservableObject {
    static let shared = AdManager()

    @Published private(set) var currentAd: SponsorAd? = AdManager.fallbackAd
    @Published private(set) var logoImage: NSImage?

    // Remote config URL — swap this to your own CDN/endpoint
    private let remoteURL = URL(string: "https://raw.githubusercontent.com/Neel2code/Recall/main/ads/current.json")!
    private let refreshInterval: TimeInterval = 3600   // 1 hour

    private var refreshTask: Task<Void, Never>?

    private init() {}

    func start() {
        Task { await refresh() }
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(refreshInterval))
                await refresh()
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func recordClick() {
        guard let ad = currentAd, let url = URL(string: ad.url) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private

    private func refresh() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            let ad = try JSONDecoder().decode(SponsorAd.self, from: data)
            currentAd = ad
            if let logoStr = ad.logoURL, let logoURL = URL(string: logoStr) {
                await fetchLogo(logoURL)
            }
        } catch {
            // Network unavailable or JSON malformed — keep showing fallback
        }
    }

    private func fetchLogo(_ url: URL) async {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data) else { return }
        logoImage = image
    }

    // MARK: - Fallback

    // Shown when network is unavailable or the remote hasn't been set up yet.
    static let fallbackAd = SponsorAd(
        id: "fallback-1",
        headline: "Advertise with Recall",
        body: "Reach thousands of developers and power users.",
        cta: "Get in touch",
        url: "mailto:neel@vermaclub.com?subject=Recall%20Sponsorship",
        logoURL: nil,
        accentColor: nil
    )
}

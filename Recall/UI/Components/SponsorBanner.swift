import SwiftUI

// MARK: - Sponsor Banner

/// A compact, non-intrusive ad unit shown at the bottom of the clipboard panel.
/// Tapping anywhere on it opens the sponsor URL. The "×" button dismisses it
/// for the current session (reappears on next launch).
struct SponsorBanner: View {
    @ObservedObject private var ads = AdManager.shared
    @State private var dismissed = false
    @State private var isHovered = false

    var body: some View {
        if !dismissed, let ad = ads.currentAd {
            banner(ad)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func banner(_ ad: SponsorAd) -> some View {
        Button(action: { ads.recordClick() }) {
            HStack(spacing: 10) {
                // Logo or SF Symbol fallback
                adLogo(ad)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("Sponsored")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .kerning(0.4)
                        Spacer()
                    }
                    Text(ad.headline)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(ad.body)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // CTA pill
                Text(ad.cta)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor(for: ad), in: Capsule())

                // Dismiss button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        dismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 18, height: 18)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                Rectangle()
                    .fill(.thinMaterial)
                    .overlay(
                        Rectangle()
                            .fill(Color.primary.opacity(isHovered ? 0.04 : 0))
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private func adLogo(_ ad: SponsorAd) -> some View {
        Group {
            if let img = ads.logoImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(accentColor(for: ad).opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(accentColor(for: ad))
                    )
            }
        }
    }

    private func accentColor(for ad: SponsorAd) -> Color {
        guard let hex = ad.accentColor else { return .accentColor }
        return Color(hex: hex) ?? .accentColor
    }
}

// MARK: - Hex Color Helper

private extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8)  & 0xFF) / 255,
            blue:  Double(val         & 0xFF) / 255
        )
    }
}

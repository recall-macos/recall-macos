import SwiftUI
import WebKit

// MARK: - Sponsor Banner
// Loads the ad.html page hosted on GitHub Pages, which contains a Google AdSense
// unit. AdSense fills the slot automatically with relevant ads (cars, apps, etc.).
// Hidden entirely when AppSettings.shared.isPro == true.

struct SponsorBanner: View {
    // GitHub Pages URL for this repo — update if you use a custom domain
    private static let adURL = URL(string: "https://recall-macos.github.io/recall-macos/ad.html")!

    var body: some View {
        AdWebView(url: Self.adURL)
            .frame(height: 60)
            .background(.thinMaterial)
    }
}

// MARK: - WKWebView wrapper

private struct AdWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Allow the AdSense script to run
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")  // transparent bg
        webView.allowsMagnification = false
        webView.enclosingScrollView?.hasVerticalScroller = false
        webView.enclosingScrollView?.hasHorizontalScroller = false

        // Load the hosted ad page
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        // Open ad clicks in the user's default browser, not inside the panel
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

import SwiftUI
import WebKit

struct WebViewRepresentable: UIViewRepresentable {
    @Bindable var tab: BrowserTab

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Use non-persistent data store for now
        // For persistent cookies, use WKWebsiteDataStore.default()
        configuration.websiteDataStore = .default()

        // Allow inline media playback
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Store reference
        tab.webView = webView

        // Load initial URL
        if let url = tab.service.url {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update tab state
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var tab: BrowserTab

        init(tab: BrowserTab) {
            self.tab = tab
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            tab.isLoading = true
            updateNavigationState(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab.isLoading = false
            tab.currentURL = webView.url
            tab.title = webView.title
            updateNavigationState(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            tab.isLoading = false
            updateNavigationState(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            tab.isLoading = false
            updateNavigationState(webView)
        }

        private func updateNavigationState(_ webView: WKWebView) {
            tab.canGoBack = webView.canGoBack
            tab.canGoForward = webView.canGoForward
        }
    }
}

#Preview {
    let service = Service(
        name: "Example",
        urlString: "https://example.com"
    )
    let tab = BrowserTab(service: service)

    return WebViewRepresentable(tab: tab)
}

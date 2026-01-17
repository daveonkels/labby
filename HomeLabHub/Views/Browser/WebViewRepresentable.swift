import SwiftUI
import WebKit

struct WebViewContainer: View {
    @Bindable var tab: BrowserTab

    var body: some View {
        VStack(spacing: 0) {
            // Browser toolbar
            BrowserToolbar(tab: tab)

            // Web content
            WebViewRepresentable(tab: tab)
        }
    }
}

struct BrowserToolbar: View {
    @Bindable var tab: BrowserTab

    var body: some View {
        HStack(spacing: 16) {
            // Back button
            Button {
                tab.webView?.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!tab.canGoBack)

            // Forward button
            Button {
                tab.webView?.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!tab.canGoForward)

            // URL display
            HStack {
                if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Text(tab.currentURL?.host ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Reload button
            Button {
                tab.webView?.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

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

    return WebViewContainer(tab: tab)
}

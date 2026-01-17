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

        // Inject safe area padding CSS to prevent content from hiding under status bar
        let safeAreaScript = WKUserScript(
            source: SafeAreaInjector.cssInjectionScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(safeAreaScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Extend content under safe areas (status bar/notch)
        webView.scrollView.contentInsetAdjustmentBehavior = .never

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

// MARK: - Safe Area CSS Injector

/// Injects CSS to add safe area padding to web pages that don't have it
enum SafeAreaInjector {
    /// JavaScript that injects CSS for safe area top padding
    /// This prevents content from hiding under the status bar/notch
    static let cssInjectionScript: String = """
    (function() {
        // Check if we've already injected (avoid double-padding on navigation)
        if (document.getElementById('homelabhub-safe-area-style')) return;

        // Get computed padding of body to check if page already has top padding
        const body = document.body;
        const computedStyle = window.getComputedStyle(body);
        const existingPadding = parseInt(computedStyle.paddingTop) || 0;

        // Only inject if the page has minimal top padding (< 20px)
        // This avoids double-padding pages that already account for safe areas
        if (existingPadding >= 20) return;

        // First, ensure viewport-fit=cover is set so env() works
        let viewport = document.querySelector('meta[name="viewport"]');
        if (viewport) {
            const content = viewport.getAttribute('content') || '';
            if (!content.includes('viewport-fit')) {
                viewport.setAttribute('content', content + ', viewport-fit=cover');
            }
        } else {
            viewport = document.createElement('meta');
            viewport.name = 'viewport';
            viewport.content = 'width=device-width, initial-scale=1, viewport-fit=cover';
            document.head.appendChild(viewport);
        }

        // Inject CSS that adds safe area padding
        const style = document.createElement('style');
        style.id = 'homelabhub-safe-area-style';
        style.textContent = `
            body {
                padding-top: env(safe-area-inset-top, 47px) !important;
                /* Smooth transition to avoid jarring layout shift */
                transition: padding-top 0.15s ease-out;
            }
            /* For pages with fixed headers, also pad the html element */
            html {
                scroll-padding-top: env(safe-area-inset-top, 47px);
            }
        `;
        document.head.appendChild(style);
    })();
    """
}

#Preview {
    let service = Service(
        name: "Example",
        urlString: "https://example.com"
    )
    let tab = BrowserTab(service: service)

    return WebViewRepresentable(tab: tab)
}

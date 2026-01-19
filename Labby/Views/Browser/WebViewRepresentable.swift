import SwiftUI
import WebKit
import os.log

private let webViewLogger = Logger(subsystem: "com.labby.app", category: "WebView")
private let debugLogger = DebugLogger.shared

struct WebViewRepresentable: UIViewRepresentable {
    @Bindable var tab: BrowserTab

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Use persistent data store for cookies, sessions, and authentication
        // This preserves login state across app launches
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

        // Load initial URL (uses restored URL if available)
        if let url = tab.urlToLoad {
            logInfo("Loading URL: \(url.absoluteString)")

            // Pre-flight check for HTTPS URLs to diagnose SSL issues
            if url.scheme == "https" {
                Task {
                    await checkSSLConnection(for: url)
                }
            }

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
        weak var tab: BrowserTab?

        init(tab: BrowserTab) {
            self.tab = tab
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            let url = webView.url?.absoluteString ?? "unknown"
            logInfo("Started navigation: \(url)")
            tab?.isLoading = true
            updateNavigationState(webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            let url = webView.url?.absoluteString ?? "unknown"
            logInfo("Navigation committed: \(url)")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let tab else { return }
            let url = webView.url?.absoluteString ?? "unknown"
            logInfo("Navigation finished: \(url)")
            tab.isLoading = false
            tab.title = webView.title
            tab.loadError = nil
            updateNavigationState(webView)
            // Persist the current URL for tab restoration
            TabManager.shared.updateTabURL(tab, url: webView.url)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            logError("Navigation failed: \(nsError.localizedDescription)")
            logDetailedError(nsError)
            tab?.isLoading = false
            tab?.loadError = describeError(nsError)
            updateNavigationState(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            let url = webView.url?.absoluteString ?? tab?.urlToLoad?.absoluteString ?? "unknown"
            logError("Failed to load \(url): \(nsError.localizedDescription)")
            logDetailedError(nsError)
            tab?.isLoading = false
            tab?.loadError = describeError(nsError)
            updateNavigationState(webView)
        }

        // MARK: - Navigation Policy

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let url = navigationAction.request.url?.absoluteString ?? "unknown"
            logDebug("Policy check: \(url)")
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                let url = httpResponse.url?.host ?? "unknown"
                if httpResponse.statusCode >= 400 {
                    logWarning("HTTP \(httpResponse.statusCode) from \(url)")
                } else {
                    logInfo("HTTP \(httpResponse.statusCode) from \(url)")
                }
            }
            decisionHandler(.allow)
        }

        // MARK: - Authentication Challenges (handles self-signed certs)

        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            let host = challenge.protectionSpace.host
            let authMethod = challenge.protectionSpace.authenticationMethod
            let port = challenge.protectionSpace.port

            logInfo("Auth challenge received: \(authMethod) for \(host):\(port)")

            // Handle server trust (SSL certificate) challenges
            if authMethod == NSURLAuthenticationMethodServerTrust {
                guard let serverTrust = challenge.protectionSpace.serverTrust else {
                    logWarning("No server trust available for \(host)")
                    completionHandler(.performDefaultHandling, nil)
                    return
                }

                // Log certificate details for debugging
                let certificateCount = SecTrustGetCertificateCount(serverTrust)
                logInfo("Certificate chain has \(certificateCount) certificate(s) for \(host)")

                // For homelab/self-hosted services, we trust ALL certificates
                // This allows self-signed, expired, and custom CA certificates to work
                logInfo("Trusting certificate for: \(host)")
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }

            // Handle client certificate challenges
            if authMethod == NSURLAuthenticationMethodClientCertificate {
                logInfo("Client certificate requested by \(host) - using default handling")
                completionHandler(.performDefaultHandling, nil)
                return
            }

            // For HTTP Basic/Digest auth, use default handling
            logDebug("Auth challenge (\(authMethod)) for \(host) - using default handling")
            completionHandler(.performDefaultHandling, nil)
        }

        // MARK: - Helpers

        private func updateNavigationState(_ webView: WKWebView) {
            tab?.canGoBack = webView.canGoBack
            tab?.canGoForward = webView.canGoForward
        }

        private func logDetailedError(_ error: NSError) {
            // Log error details for debugging
            var details = "Domain: \(error.domain), Code: \(error.code)"

            if let failingURL = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
                details += ", URL: \(failingURL.absoluteString)"
            }

            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                details += ", Underlying: \(underlyingError.domain) (\(underlyingError.code))"
            }

            logError(details)

            // Log human-readable explanation
            let explanation = explainError(error)
            if !explanation.isEmpty {
                logError(explanation)
            }
        }

        private func explainError(_ error: NSError) -> String {
            switch error.code {
            case NSURLErrorCancelled:
                return "Navigation was cancelled"
            case NSURLErrorTimedOut:
                return "Connection timed out - server may be slow or unreachable"
            case NSURLErrorCannotFindHost:
                return "Cannot find host - check DNS or hostname"
            case NSURLErrorCannotConnectToHost:
                return "Cannot connect - server may be down"
            case NSURLErrorNetworkConnectionLost:
                return "Network connection lost"
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection"
            case NSURLErrorSecureConnectionFailed:
                return "SSL/TLS connection failed - check server certificate"
            case NSURLErrorServerCertificateHasBadDate:
                return "Server certificate expired or not yet valid"
            case NSURLErrorServerCertificateUntrusted:
                return "Server certificate not trusted (self-signed?)"
            case NSURLErrorServerCertificateHasUnknownRoot:
                return "Unknown certificate authority"
            case NSURLErrorServerCertificateNotYetValid:
                return "Server certificate not yet valid"
            case NSURLErrorAppTransportSecurityRequiresSecureConnection:
                return "App Transport Security blocked connection"
            default:
                return ""
            }
        }

        private func describeError(_ error: NSError) -> String {
            switch error.code {
            case NSURLErrorCancelled:
                return "Navigation cancelled"
            case NSURLErrorTimedOut:
                return "Connection timed out"
            case NSURLErrorCannotFindHost:
                return "Cannot find server"
            case NSURLErrorCannotConnectToHost:
                return "Cannot connect to server"
            case NSURLErrorNetworkConnectionLost:
                return "Connection lost"
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection"
            case NSURLErrorSecureConnectionFailed:
                return "SSL connection failed"
            case NSURLErrorServerCertificateHasBadDate:
                return "Certificate expired"
            case NSURLErrorServerCertificateUntrusted:
                return "Certificate not trusted"
            case NSURLErrorServerCertificateHasUnknownRoot:
                return "Unknown certificate authority"
            case NSURLErrorServerCertificateNotYetValid:
                return "Certificate not yet valid"
            case NSURLErrorAppTransportSecurityRequiresSecureConnection:
                return "Secure connection required"
            default:
                return error.localizedDescription
            }
        }
    }
}

// MARK: - SSL Diagnostics

/// Pre-flight check to diagnose SSL connection issues
/// Uses URLSession which gives us more control over certificate handling
private func checkSSLConnection(for url: URL) async {
    logInfo("SSL check: Testing connection to \(url.host ?? "unknown")")

    // Create a session that trusts all certificates for diagnostic purposes
    let session = URLSession(
        configuration: .ephemeral,
        delegate: SSLBypassDelegate(),
        delegateQueue: nil
    )

    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"
    request.timeoutInterval = 10

    do {
        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            logInfo("SSL check: Success! HTTP \(httpResponse.statusCode) from \(url.host ?? "unknown")")
        }
    } catch let error as NSError {
        logError("SSL check failed: \(error.localizedDescription)")
        logError("SSL check error details: domain=\(error.domain) code=\(error.code)")

        // Log specific SSL error information
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorSecureConnectionFailed:
                logError("SSL check: Secure connection failed - server may use incompatible TLS version or cipher")
            case NSURLErrorServerCertificateHasBadDate:
                logError("SSL check: Certificate date invalid")
            case NSURLErrorServerCertificateUntrusted:
                logError("SSL check: Certificate not trusted")
            case NSURLErrorServerCertificateHasUnknownRoot:
                logError("SSL check: Unknown certificate authority")
            case NSURLErrorClientCertificateRejected:
                logError("SSL check: Client certificate rejected")
            case NSURLErrorClientCertificateRequired:
                logError("SSL check: Client certificate required")
            default:
                break
            }
        }

        // Check for underlying SSL error
        if let sslError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            logError("SSL check underlying error: \(sslError.domain) code=\(sslError.code)")
            if let sslErrorMessage = sslError.userInfo[NSLocalizedDescriptionKey] as? String {
                logError("SSL check underlying message: \(sslErrorMessage)")
            }
        }
    }

    session.invalidateAndCancel()
}

/// URLSession delegate that bypasses SSL certificate validation for diagnostics
private class SSLBypassDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - Dual Logging Helpers

private func logInfo(_ message: String) {
    webViewLogger.info("\(message)")
    debugLogger.info(message, category: "WebView")
}

private func logDebug(_ message: String) {
    webViewLogger.debug("\(message)")
    debugLogger.debug(message, category: "WebView")
}

private func logWarning(_ message: String) {
    webViewLogger.warning("\(message)")
    debugLogger.warning(message, category: "WebView")
}

private func logError(_ message: String) {
    webViewLogger.error("\(message)")
    debugLogger.error(message, category: "WebView")
}

// MARK: - Safe Area CSS Injector

/// Injects CSS to add safe area padding to web pages that don't have it
enum SafeAreaInjector {
    /// JavaScript that injects CSS for safe area top padding
    /// This prevents content from hiding under the status bar/notch
    static let cssInjectionScript: String = """
    (function() {
        // Check if we've already injected (avoid double-padding on navigation)
        if (document.getElementById('labby-safe-area-style')) return;

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
        style.id = 'labby-safe-area-style';
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

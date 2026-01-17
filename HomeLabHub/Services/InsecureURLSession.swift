import Foundation

/// Shared URLSession that bypasses SSL certificate validation for homelab self-signed certs.
/// Use this for all network requests in the app to support self-signed certificates.
enum InsecureURLSession {
    /// URLSession configured to accept self-signed certificates
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config, delegate: InsecureSSLDelegate.shared, delegateQueue: nil)
    }()
}

// MARK: - SSL Certificate Bypass for Homelab Self-Signed Certs

/// URLSession delegate that accepts all SSL certificates (including self-signed)
final class InsecureSSLDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    static let shared = InsecureSSLDelegate()

    private override init() {
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Accept any server certificate for homelab self-signed certs
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

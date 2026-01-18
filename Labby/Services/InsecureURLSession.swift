import Foundation

/// Shared URLSession that handles SSL certificate validation based on trusted domains.
/// Only bypasses SSL validation for domains explicitly trusted by the user.
enum LabbyURLSession {
    /// URLSession configured to handle self-signed certificates for trusted domains
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config, delegate: TrustedDomainSSLDelegate.shared, delegateQueue: nil)
    }()
}

// MARK: - Legacy Alias (for backward compatibility during migration)

/// Legacy alias - use LabbyURLSession.shared instead
enum InsecureURLSession {
    static var shared: URLSession { LabbyURLSession.shared }
}

// MARK: - SSL Certificate Handling for Trusted Domains

/// URLSession delegate that accepts self-signed certificates only for trusted domains.
/// External services (CDNs, etc.) use standard SSL validation.
final class TrustedDomainSSLDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    static let shared = TrustedDomainSSLDelegate()

    private override init() {
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // Check if this host is in our trusted list
        if TrustedDomainManager.shared.isHostTrusted(host) {
            // Accept the certificate for trusted homelab domains
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // Use default SSL validation for untrusted domains (external CDNs, etc.)
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

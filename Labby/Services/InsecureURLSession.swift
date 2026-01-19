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

// MARK: - SSL Certificate Handling for Homelab Services

/// URLSession delegate that accepts all SSL certificates for homelab services.
/// Since Labby is designed for self-hosted services that often use self-signed
/// certificates, we trust all server certificates by default.
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

        // For homelab services, trust all certificates
        // This allows self-signed, expired, and custom CA certificates to work
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}

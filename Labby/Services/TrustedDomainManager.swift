import Foundation

/// Manages the list of domains that should bypass SSL certificate validation.
/// This allows homelab servers with self-signed certificates to work while
/// keeping standard SSL validation for external services.
final class TrustedDomainManager: @unchecked Sendable {
    static let shared = TrustedDomainManager()

    private var trustedHosts: Set<String> = []
    private let lock = NSLock()

    private init() {}

    /// Adds a host to the trusted list
    func trustHost(_ host: String) {
        lock.lock()
        defer { lock.unlock() }
        trustedHosts.insert(host.lowercased())
    }

    /// Adds multiple hosts to the trusted list
    func trustHosts(_ hosts: [String]) {
        lock.lock()
        defer { lock.unlock() }
        for host in hosts {
            trustedHosts.insert(host.lowercased())
        }
    }

    /// Removes a host from the trusted list
    func untrustHost(_ host: String) {
        lock.lock()
        defer { lock.unlock() }
        trustedHosts.remove(host.lowercased())
    }

    /// Clears all trusted hosts
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        trustedHosts.removeAll()
    }

    /// Checks if a host is in the trusted list
    func isHostTrusted(_ host: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return trustedHosts.contains(host.lowercased())
    }

    /// Returns all currently trusted hosts (for debugging/UI)
    var allTrustedHosts: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(trustedHosts).sorted()
    }
}

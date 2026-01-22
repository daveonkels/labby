import Foundation
import SwiftData

/// Health checker that runs on the MainActor to safely interact with SwiftData
@MainActor
final class HealthChecker {
    static let shared = HealthChecker()

    private var monitoringTask: Task<Void, Never>?
    private let checkInterval: TimeInterval = 60 // seconds between full checks
    private let cacheInterval: TimeInterval = 55 // skip if checked within this time
    private let maxConcurrentChecks = 5

    /// URLSession for health checks that trusts all SSL certificates
    /// Used for services with trustSelfSignedCertificates = true
    private nonisolated static let trustingSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config, delegate: TrustingHealthCheckDelegate.shared, delegateQueue: nil)
    }()

    /// URLSession for health checks with standard SSL validation
    /// Used for services with trustSelfSignedCertificates = false
    private nonisolated static let strictSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config, delegate: StrictHealthCheckDelegate.shared, delegateQueue: nil)
    }()

    private init() {}

    /// Starts background health monitoring. Restarts with new context if called again.
    func startMonitoring(modelContext: ModelContext) {
        // Cancel existing monitoring task if running
        monitoringTask?.cancel()

        monitoringTask = Task {
            while !Task.isCancelled {
                await checkAllServices(modelContext: modelContext)
                try? await Task.sleep(for: .seconds(checkInterval))
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    /// Checks all services, respecting cache interval
    func checkAllServices(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Service>()

        guard let services = try? modelContext.fetch(descriptor) else {
            return
        }

        // Filter to only services that need checking and extract data for parallel processing
        let now = Date()
        var checkTasks: [(service: Service, url: URL, name: String, trustSSL: Bool)] = []

        for service in services {
            guard let url = service.url else { continue }
            guard let lastCheck = service.lastHealthCheck else {
                checkTasks.append((service, url, service.name, service.trustSelfSignedCertificates))
                continue
            }
            if now.timeIntervalSince(lastCheck) >= cacheInterval {
                checkTasks.append((service, url, service.name, service.trustSelfSignedCertificates))
            }
        }

        if checkTasks.isEmpty {
            return
        }

        // Perform health checks with limited concurrency
        await withTaskGroup(of: (Int, Bool).self) { group in
            var activeCount = 0

            for (index, task) in checkTasks.enumerated() {
                // Wait if we've hit the concurrency limit
                if activeCount >= maxConcurrentChecks {
                    if let result = await group.next() {
                        checkTasks[result.0].service.isHealthy = result.1
                        checkTasks[result.0].service.lastHealthCheck = Date()
                    }
                    activeCount -= 1
                }

                group.addTask {
                    let isHealthy = await Self.performHealthCheck(url: task.url, name: task.name, trustSSL: task.trustSSL)
                    return (index, isHealthy)
                }
                activeCount += 1
            }

            // Collect remaining results
            for await result in group {
                checkTasks[result.0].service.isHealthy = result.1
                checkTasks[result.0].service.lastHealthCheck = Date()
            }
        }

        try? modelContext.save()
    }

    /// Performs the actual HTTP health check (no Service access)
    nonisolated static func performHealthCheck(url: URL, name: String, trustSSL: Bool = true) async -> Bool {
        let session = trustSSL ? Self.trustingSession : Self.strictSession

        // Try HEAD first for efficiency
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        do {
            let (_, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                // If HEAD returns any 5xx error, fall back to GET
                // Many servers/reverse proxies don't properly support HEAD:
                // - 501: Not Implemented (e.g., Transmission)
                // - 502: Bad Gateway (e.g., NZBGet behind reverse proxy)
                // - 503: Service Unavailable (e.g., Blue Iris)
                if (500...599).contains(httpResponse.statusCode) {
                    return await Self.performGetHealthCheck(url: url, name: name, trustSSL: trustSSL)
                }

                // Any response from 200-499 (including redirects 3xx) means server is online
                // We don't follow redirects, so 3xx responses come back directly
                let isHealthy = (200...499).contains(httpResponse.statusCode)
                return isHealthy
            }
            return false
        } catch {
            // Check if the error is because we blocked a redirect (server is actually online)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorHTTPTooManyRedirects {
                return true
            }
            return false
        }
    }

    /// Fallback GET health check for servers that don't support HEAD
    nonisolated private static func performGetHealthCheck(url: URL, name: String, trustSSL: Bool = true) async -> Bool {
        let session = trustSSL ? Self.trustingSession : Self.strictSession

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        do {
            let (_, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                // Any response from 200-499 (including redirects 3xx) means server is online
                let isHealthy = (200...499).contains(httpResponse.statusCode)
                return isHealthy
            }
            return false
        } catch {
            // Check if the error is because we blocked a redirect (server is actually online)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorHTTPTooManyRedirects {
                return true
            }
            return false
        }
    }

    /// Force refresh a single service (ignores cache)
    func refreshService(_ service: Service) async {
        guard let url = service.url else {
            service.isHealthy = false
            service.lastHealthCheck = Date()
            return
        }

        let isHealthy = await Self.performHealthCheck(url: url, name: service.name, trustSSL: service.trustSelfSignedCertificates)
        service.isHealthy = isHealthy
        service.lastHealthCheck = Date()
    }
}

// MARK: - Health Check Session Delegates

/// URLSession delegate for health checks that trusts ALL SSL certificates.
/// Used when service.trustSelfSignedCertificates = true
final class TrustingHealthCheckDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = TrustingHealthCheckDelegate()

    private override init() {
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Trust all certificates for homelab services
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Don't follow redirects - if we got a redirect response, the server is online
        // This prevents issues with HTTPS->HTTP redirects being blocked by ATS
        completionHandler(nil)
    }
}

/// URLSession delegate for health checks with STRICT SSL validation.
/// Used when service.trustSelfSignedCertificates = false
final class StrictHealthCheckDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = StrictHealthCheckDelegate()

    private override init() {
        super.init()
    }

    // No SSL override - uses default system validation

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Don't follow redirects - if we got a redirect response, the server is online
        completionHandler(nil)
    }
}

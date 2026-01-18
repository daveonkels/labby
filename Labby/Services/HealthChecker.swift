import Foundation
import SwiftData

actor HealthChecker {
    static let shared = HealthChecker()

    private var monitoringTask: Task<Void, Never>?
    private let checkInterval: TimeInterval = 60 // seconds between full checks
    private let cacheInterval: TimeInterval = 55 // skip if checked within this time
    private let maxConcurrentChecks = 5

    /// URLSession with shorter timeouts for health checks (uses trusted domain SSL delegate)
    private static let healthCheckSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config, delegate: TrustedDomainSSLDelegate.shared, delegateQueue: nil)
    }()

    private init() {}

    /// Starts background health monitoring. Restarts with new context if called again.
    func startMonitoring(modelContext: ModelContext) {
        // Cancel existing monitoring task if running
        if monitoringTask != nil {
            monitoringTask?.cancel()
        }

        monitoringTask = Task { @MainActor in
            while !Task.isCancelled {
                await HealthChecker.shared.checkAllServices(modelContext: modelContext)
                try? await Task.sleep(for: .seconds(checkInterval))
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    /// Checks all services, respecting cache interval
    @MainActor
    func checkAllServices(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Service>()

        guard let services = try? modelContext.fetch(descriptor) else {
            return
        }

        // Filter to only services that need checking and extract data for parallel processing
        let now = Date()
        var checkTasks: [(service: Service, url: URL, name: String)] = []

        for service in services {
            guard let url = service.url else { continue }
            guard let lastCheck = service.lastHealthCheck else {
                checkTasks.append((service, url, service.name))
                continue
            }
            if now.timeIntervalSince(lastCheck) >= cacheInterval {
                checkTasks.append((service, url, service.name))
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
                    let isHealthy = await self.performHealthCheck(url: task.url, name: task.name)
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
    nonisolated func performHealthCheck(url: URL, name: String) async -> Bool {

        // Try HEAD first for efficiency
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        do {
            let (_, response) = try await Self.healthCheckSession.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                // If HEAD returns any 5xx error, fall back to GET
                // Many servers/reverse proxies don't properly support HEAD:
                // - 501: Not Implemented (e.g., Transmission)
                // - 502: Bad Gateway (e.g., NZBGet behind reverse proxy)
                // - 503: Service Unavailable (e.g., Blue Iris)
                if (500...599).contains(httpResponse.statusCode) {
                    return await performGetHealthCheck(url: url, name: name)
                }

                let isHealthy = (200...499).contains(httpResponse.statusCode)
                return isHealthy
            }
            return false
        } catch {
            return false
        }
    }

    /// Fallback GET health check for servers that don't support HEAD
    nonisolated private func performGetHealthCheck(url: URL, name: String) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        do {
            let (_, response) = try await Self.healthCheckSession.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                let isHealthy = (200...499).contains(httpResponse.statusCode)
                return isHealthy
            }
            return false
        } catch {
            return false
        }
    }

    /// Force refresh a single service (ignores cache)
    @MainActor
    func refreshService(_ service: Service) async {
        guard let url = service.url else {
            service.isHealthy = false
            service.lastHealthCheck = Date()
            return
        }

        let isHealthy = await performHealthCheck(url: url, name: service.name)
        service.isHealthy = isHealthy
        service.lastHealthCheck = Date()
    }
}

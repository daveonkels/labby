import Foundation
import SwiftData

actor HealthChecker {
    static let shared = HealthChecker()

    private var isRunning = false
    private var monitoringTask: Task<Void, Never>?
    private let checkInterval: TimeInterval = 60 // seconds between full checks
    private let cacheInterval: TimeInterval = 55 // skip if checked within this time
    private let maxConcurrentChecks = 5

    private init() {}

    /// Starts background health monitoring. Safe to call multiple times.
    func startMonitoring(modelContext: ModelContext) async {
        // Already running - don't start another loop
        guard !isRunning else {
            print("🏥 [Health] Monitoring already running, skipping start")
            return
        }

        isRunning = true
        print("🏥 [Health] Starting health monitoring (interval: \(Int(checkInterval))s)")

        while isRunning {
            await checkAllServices(modelContext: modelContext)
            try? await Task.sleep(for: .seconds(checkInterval))
        }
    }

    func stopMonitoring() {
        print("🏥 [Health] Stopping health monitoring")
        isRunning = false
    }

    /// Checks all services, respecting cache interval
    func checkAllServices(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Service>()

        guard let services = try? modelContext.fetch(descriptor) else {
            print("🏥 [Health] Failed to fetch services")
            return
        }

        // Filter to only services that need checking
        let now = Date()
        let servicesToCheck = services.filter { service in
            guard service.url != nil else { return false }
            guard let lastCheck = service.lastHealthCheck else { return true }
            return now.timeIntervalSince(lastCheck) >= cacheInterval
        }

        if servicesToCheck.isEmpty {
            print("🏥 [Health] All services recently checked, skipping")
            return
        }

        print("🏥 [Health] Checking \(servicesToCheck.count)/\(services.count) services")

        // Use limited concurrency to avoid connection spam
        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0

            for service in servicesToCheck {
                // Wait if we've hit the concurrency limit
                if activeCount >= maxConcurrentChecks {
                    await group.next()
                    activeCount -= 1
                }

                group.addTask {
                    await self.checkService(service)
                }
                activeCount += 1
            }

            // Wait for remaining tasks
            await group.waitForAll()
        }

        try? modelContext.save()
        print("🏥 [Health] Check complete")
    }

    /// Checks a single service's health
    func checkService(_ service: Service) async {
        guard let url = service.url else {
            await MainActor.run {
                service.isHealthy = false
                service.lastHealthCheck = Date()
            }
            return
        }

        // Use GET instead of HEAD - more reliable across services
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        // Only read a tiny bit of the response
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                let isHealthy = (200...499).contains(httpResponse.statusCode)
                await MainActor.run {
                    service.isHealthy = isHealthy
                    service.lastHealthCheck = Date()
                }
                if !isHealthy {
                    print("🏥 [Health] \(service.name): HTTP \(httpResponse.statusCode)")
                }
            } else {
                await MainActor.run {
                    service.isHealthy = false
                    service.lastHealthCheck = Date()
                }
            }
        } catch let error as URLError {
            // Connection refused, timeout, etc. - service is down
            await MainActor.run {
                service.isHealthy = false
                service.lastHealthCheck = Date()
            }
            // Only log meaningful errors, not cancellations
            if error.code != .cancelled {
                print("🏥 [Health] \(service.name): \(error.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                service.isHealthy = false
                service.lastHealthCheck = Date()
            }
        }
    }

    /// Force refresh a single service (ignores cache)
    func refreshService(_ service: Service) async {
        await checkService(service)
    }
}

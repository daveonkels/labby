import Foundation
import SwiftData

actor HealthChecker {
    static let shared = HealthChecker()

    private var isRunning = false
    private var checkInterval: TimeInterval = 60 // seconds

    private init() {}

    func startMonitoring(modelContext: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true

        while isRunning {
            await checkAllServices(modelContext: modelContext)
            try? await Task.sleep(for: .seconds(checkInterval))
        }
    }

    func stopMonitoring() {
        isRunning = false
    }

    func checkAllServices(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Service>()

        guard let services = try? modelContext.fetch(descriptor) else {
            return
        }

        await withTaskGroup(of: Void.self) { group in
            for service in services {
                group.addTask {
                    await self.checkService(service)
                }
            }
        }

        try? modelContext.save()
    }

    func checkService(_ service: Service) async {
        guard let url = service.url else {
            service.isHealthy = false
            service.lastHealthCheck = Date()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                service.isHealthy = (200...399).contains(httpResponse.statusCode)
            } else {
                service.isHealthy = false
            }
        } catch {
            service.isHealthy = false
        }

        service.lastHealthCheck = Date()
    }
}

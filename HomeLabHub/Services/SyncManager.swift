import Foundation
import SwiftData

@Observable
final class SyncManager {
    static let shared = SyncManager()

    var isSyncing = false
    var lastError: Error?
    var lastSyncedCount: Int = 0

    private init() {}

    /// Syncs services from a Homepage connection
    @MainActor
    func syncConnection(_ connection: HomepageConnection, modelContext: ModelContext) async {
        guard let baseURL = connection.baseURL else {
            lastError = SyncError.invalidURL
            return
        }

        isSyncing = true
        lastError = nil

        do {
            print("🔄 [Sync] Starting sync for: \(baseURL)")
            let client = HomepageClient(baseURL: baseURL)
            let parsedServices = try await client.fetchServices()
            print("🔄 [Sync] Received \(parsedServices.count) services from parser")

            // Get existing synced services (not manually added)
            let descriptor = FetchDescriptor<Service>(
                predicate: #Predicate { service in
                    !service.isManuallyAdded
                }
            )

            let existingServices = (try? modelContext.fetch(descriptor)) ?? []
            let existingServiceIds = Set(existingServices.compactMap { $0.homepageServiceId })

            var syncedCount = 0

            // Process fetched services
            for parsedService in parsedServices {
                if existingServiceIds.contains(parsedService.id) {
                    // Update existing service
                    if let existing = existingServices.first(where: { $0.homepageServiceId == parsedService.id }) {
                        existing.name = parsedService.name
                        existing.urlString = parsedService.href ?? ""
                        existing.iconURLString = parsedService.iconURL
                        existing.category = parsedService.category
                        existing.sortOrder = parsedService.sortOrder
                    }
                } else {
                    // Create new service
                    let service = Service(
                        name: parsedService.name,
                        urlString: parsedService.href ?? "",
                        iconURLString: parsedService.iconURL,
                        category: parsedService.category,
                        sortOrder: parsedService.sortOrder,
                        isManuallyAdded: false,
                        homepageServiceId: parsedService.id
                    )
                    modelContext.insert(service)
                }
                syncedCount += 1
            }

            // Remove services that no longer exist in Homepage
            let fetchedIds = Set(parsedServices.map { $0.id })
            for existing in existingServices {
                if let homepageId = existing.homepageServiceId, !fetchedIds.contains(homepageId) {
                    modelContext.delete(existing)
                }
            }

            // Update connection sync timestamp
            connection.lastSync = Date()
            lastSyncedCount = syncedCount

            try modelContext.save()

        } catch {
            lastError = error
            print("❌ [Sync] Sync failed: \(error)")
            print("❌ [Sync] Error details: \(String(describing: error))")
        }

        isSyncing = false
    }

    /// Syncs all enabled connections
    @MainActor
    func syncAllConnections(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<HomepageConnection>(
            predicate: #Predicate { $0.syncEnabled }
        )

        guard let connections = try? modelContext.fetch(descriptor) else {
            return
        }

        for connection in connections {
            await syncConnection(connection, modelContext: modelContext)
        }
    }
}

enum SyncError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Homepage URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parseError(let message):
            return "Failed to parse Homepage config: \(message)"
        }
    }
}

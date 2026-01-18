import Foundation
import SwiftData

@Observable
final class SyncManager {
    static let shared = SyncManager()

    var isSyncing = false
    var lastError: Error?
    var lastSyncedCount: Int = 0

    private init() {}

    /// Syncs services and bookmarks from a Homepage connection
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
            let (parsedServices, parsedBookmarks) = try await client.fetchAll()
            print("🔄 [Sync] Received \(parsedServices.count) services, \(parsedBookmarks.count) bookmarks")

            // Sync services
            await syncServices(parsedServices, modelContext: modelContext)

            // Sync bookmarks
            await syncBookmarks(parsedBookmarks, modelContext: modelContext)

            // Clean up orphaned category icon preferences (handles renamed categories)
            await cleanupOrphanedCategoryPreferences(modelContext: modelContext)

            // Update connection sync timestamp
            connection.lastSync = Date()
            lastSyncedCount = parsedServices.count + parsedBookmarks.count

            try modelContext.save()

        } catch {
            lastError = error
            print("❌ [Sync] Sync failed: \(error)")
            print("❌ [Sync] Error details: \(String(describing: error))")
        }

        isSyncing = false
    }

    @MainActor
    private func syncServices(_ parsedServices: [ParsedService], modelContext: ModelContext) async {
        // Get existing synced services (not manually added)
        let descriptor = FetchDescriptor<Service>(
            predicate: #Predicate { service in
                !service.isManuallyAdded
            }
        )

        let existingServices = (try? modelContext.fetch(descriptor)) ?? []
        let existingServiceIds = Set(existingServices.compactMap { $0.homepageServiceId })

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
        }

        // Remove services that no longer exist in Homepage
        if !parsedServices.isEmpty {
            let fetchedIds = Set(parsedServices.map { $0.id })
            var deletedCount = 0
            for existing in existingServices {
                if let homepageId = existing.homepageServiceId, !fetchedIds.contains(homepageId) {
                    modelContext.delete(existing)
                    deletedCount += 1
                }
            }
            if deletedCount > 0 {
                print("🔄 [Sync] Removed \(deletedCount) services no longer in Homepage")
            }
        }
    }

    @MainActor
    private func syncBookmarks(_ parsedBookmarks: [ParsedBookmark], modelContext: ModelContext) async {
        // Get existing bookmarks
        let descriptor = FetchDescriptor<Bookmark>()
        let existingBookmarks = (try? modelContext.fetch(descriptor)) ?? []
        let existingBookmarkIds = Set(existingBookmarks.compactMap { $0.homepageBookmarkId })

        // Process fetched bookmarks
        for parsedBookmark in parsedBookmarks {
            if existingBookmarkIds.contains(parsedBookmark.id) {
                // Update existing bookmark
                if let existing = existingBookmarks.first(where: { $0.homepageBookmarkId == parsedBookmark.id }) {
                    existing.name = parsedBookmark.name
                    existing.abbreviation = parsedBookmark.abbreviation
                    existing.urlString = parsedBookmark.href
                    existing.category = parsedBookmark.category
                    existing.sortOrder = parsedBookmark.sortOrder
                }
            } else {
                // Create new bookmark
                let bookmark = Bookmark(
                    name: parsedBookmark.name,
                    abbreviation: parsedBookmark.abbreviation,
                    urlString: parsedBookmark.href,
                    category: parsedBookmark.category,
                    sortOrder: parsedBookmark.sortOrder,
                    homepageBookmarkId: parsedBookmark.id
                )
                modelContext.insert(bookmark)
            }
        }

        // Remove bookmarks that no longer exist in Homepage
        if !parsedBookmarks.isEmpty {
            let fetchedIds = Set(parsedBookmarks.map { $0.id })
            var deletedCount = 0
            for existing in existingBookmarks {
                if let homepageId = existing.homepageBookmarkId, !fetchedIds.contains(homepageId) {
                    modelContext.delete(existing)
                    deletedCount += 1
                }
            }
            if deletedCount > 0 {
                print("🔄 [Sync] Removed \(deletedCount) bookmarks no longer in Homepage")
            }
        }
    }

    /// Removes category icon preferences for categories that no longer exist
    /// This handles the case where a user renames a category in Homepage
    @MainActor
    private func cleanupOrphanedCategoryPreferences(modelContext: ModelContext) async {
        // Get all current category names from services
        let servicesDescriptor = FetchDescriptor<Service>()
        let services = (try? modelContext.fetch(servicesDescriptor)) ?? []
        let serviceCategories = Set(services.compactMap { $0.category?.lowercased() })

        // Get all current category names from bookmarks
        let bookmarksDescriptor = FetchDescriptor<Bookmark>()
        let bookmarks = (try? modelContext.fetch(bookmarksDescriptor)) ?? []
        let bookmarkCategories = Set(bookmarks.compactMap { $0.category?.lowercased() })

        // Combine all valid category names
        let validCategories = serviceCategories.union(bookmarkCategories)

        // Get all saved category icon preferences
        let prefsDescriptor = FetchDescriptor<CategoryIconPreference>()
        let preferences = (try? modelContext.fetch(prefsDescriptor)) ?? []

        // Delete preferences for categories that no longer exist
        var deletedCount = 0
        for preference in preferences {
            if !validCategories.contains(preference.categoryName) {
                modelContext.delete(preference)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            print("🔄 [Sync] Removed \(deletedCount) orphaned category icon preferences")
        }
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

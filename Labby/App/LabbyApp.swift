import SwiftUI
import SwiftData

@main
struct LabbyApp: App {
    let sharedModelContainer: ModelContainer

    init() {
        configureNavigationBarAppearance()
        configureTabBarAppearance()
        // Clear debug logs from previous sessions
        DebugLogger.shared.clear()

        // Initialize ModelContainer with recovery logic
        sharedModelContainer = Self.createModelContainer()
    }

    private static func createModelContainer() -> ModelContainer {
        let schema = Schema([
            Service.self,
            HomepageConnection.self,
            AppSettings.self,
            Bookmark.self,
            CategoryIconPreference.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Log the error for debugging
            print("⚠️ ModelContainer creation failed: \(error)")
            print("⚠️ Attempting recovery by deleting corrupted database...")

            // Attempt recovery: delete corrupted database and retry
            if deleteCorruptedDatabase() {
                do {
                    return try ModelContainer(for: schema, configurations: [modelConfiguration])
                } catch {
                    print("❌ Recovery failed: \(error)")
                }
            }

            // Last resort: use in-memory storage so app doesn't crash
            print("⚠️ Using in-memory storage as fallback")
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                // This should never happen, but if it does, we have no choice
                fatalError("Could not create even in-memory ModelContainer: \(error)")
            }
        }
    }

    /// Attempts to delete the corrupted SwiftData database
    private static func deleteCorruptedDatabase() -> Bool {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }

        // SwiftData stores its database in Application Support with default.store name
        let storeURL = appSupport.appendingPathComponent("default.store")

        // Delete all related files (.store, .store-shm, .store-wal)
        let filesToDelete = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal")
        ]

        var success = true
        for url in filesToDelete {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                    print("✅ Deleted: \(url.lastPathComponent)")
                } catch {
                    print("❌ Failed to delete \(url.lastPathComponent): \(error)")
                    success = false
                }
            }
        }

        return success
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Root view that applies the adaptive tint color based on color scheme
struct AppRootView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ContentView()
            .tint(LabbyColors.primary(for: colorScheme))
    }
}

// MARK: - Appearance Configuration

/// Configures the navigation bar appearance with monospaced fonts for the retro CRT aesthetic
private func configureNavigationBarAppearance() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithDefaultBackground()

    // Large title (e.g., "Dashboard", "Settings")
    appearance.largeTitleTextAttributes = [
        .font: UIFont.monospacedSystemFont(ofSize: 34, weight: .black)
    ]

    // Inline/standard title
    appearance.titleTextAttributes = [
        .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .bold)
    ]

    UINavigationBar.appearance().scrollEdgeAppearance = appearance
    UINavigationBar.appearance().standardAppearance = appearance
    UINavigationBar.appearance().compactAppearance = appearance
}

/// Configures the tab bar appearance with monospaced fonts
private func configureTabBarAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()

    // Tab bar item text attributes
    let itemAppearance = UITabBarItemAppearance()
    let normalAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
    ]
    let selectedAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
    ]

    itemAppearance.normal.titleTextAttributes = normalAttributes
    itemAppearance.selected.titleTextAttributes = selectedAttributes

    appearance.stackedLayoutAppearance = itemAppearance
    appearance.inlineLayoutAppearance = itemAppearance
    appearance.compactInlineLayoutAppearance = itemAppearance

    UITabBar.appearance().scrollEdgeAppearance = appearance
    UITabBar.appearance().standardAppearance = appearance
}

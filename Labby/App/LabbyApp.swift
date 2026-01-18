import SwiftUI
import SwiftData

@main
struct LabbyApp: App {
    init() {
        configureNavigationBarAppearance()
        configureTabBarAppearance()
    }

    var sharedModelContainer: ModelContainer = {
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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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

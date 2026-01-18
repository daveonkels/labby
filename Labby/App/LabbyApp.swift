import SwiftUI
import SwiftData

@main
struct LabbyApp: App {
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

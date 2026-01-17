import SwiftUI
import SwiftData

@main
struct HomeLabHubApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Service.self,
            HomepageConnection.self,
            AppSettings.self,
            Bookmark.self
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

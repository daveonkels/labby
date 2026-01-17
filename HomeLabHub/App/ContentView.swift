import SwiftUI
import SwiftData

// Environment key for switching tabs
struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: Binding<ContentView.Tab> = .constant(.dashboard)
}

extension EnvironmentValues {
    var selectedTab: Binding<ContentView.Tab> {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [HomepageConnection]

    @State private var selectedTab: Tab = .dashboard

    enum Tab {
        case dashboard
        case browser
        case settings
    }

    var body: some View {
        Group {
            if connections.isEmpty {
                OnboardingView()
            } else {
                MainTabView(selectedTab: $selectedTab)
                    .environment(\.selectedTab, $selectedTab)
            }
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
                .tag(ContentView.Tab.dashboard)

            BrowserContainerView()
                .tabItem {
                    Label("Browser", systemImage: "globe")
                }
                .tag(ContentView.Tab.browser)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(ContentView.Tab.settings)
        }
    }
}

struct OnboardingView: View {
    @State private var showingSetup = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 12) {
                Text("Welcome to HomeLabHub")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Connect to your Homepage dashboard to get started")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button {
                showingSetup = true
            } label: {
                Text("Connect to Homepage")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $showingSetup) {
            ConnectionSetupView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Service.self, HomepageConnection.self], inMemory: true)
}

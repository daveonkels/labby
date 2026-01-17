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

    enum Tab: Hashable {
        case dashboard
        case browser
        case settings
        case search
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
    @State private var searchText = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "square.grid.2x2.fill", value: .dashboard) {
                DashboardView(searchText: $searchText)
            }

            Tab("Browser", systemImage: "globe", value: .browser) {
                BrowserContainerView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }

            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                NavigationStack {
                    SearchResultsView(searchText: $searchText)
                }
            }
        }
    }
}

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingSetup = false
    @State private var animationPhase = 0

    private let features = [
        ("square.grid.2x2.fill", "Dashboard", "View all your services at a glance"),
        ("heart.text.square.fill", "Health Monitoring", "Real-time service status updates"),
        ("globe", "Built-in Browser", "Access services without leaving the app"),
        ("arrow.triangle.2.circlepath", "Auto Sync", "Connect to Homepage for automatic sync")
    ]

    var body: some View {
        ZStack {
            // Animated background
            OnboardingBackground()

            VStack(spacing: 0) {
                Spacer()

                // Hero section
                VStack(spacing: 24) {
                    // Animated logo
                    ZStack {
                        // Orbiting icons
                        ForEach(0..<4, id: \.self) { index in
                            Image(systemName: orbitingIcons[index])
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 40, height: 40)
                                .background {
                                    Circle()
                                        .fill(orbitingColors[index].gradient)
                                }
                                .clipShape(Circle())
                                .offset(orbitOffset(for: index))
                                .animation(
                                    .linear(duration: 12)
                                        .repeatForever(autoreverses: false),
                                    value: animationPhase
                                )
                        }

                        // Center icon
                        Image(systemName: "server.rack")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 100, height: 100)
                            .background {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.indigo],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.5), radius: 20, y: 10)
                            }
                            .clipShape(Circle())
                    }
                    .frame(width: 200, height: 200)

                    VStack(spacing: 8) {
                        Text("HomeLabHub")
                            .font(.largeTitle.weight(.bold))

                        Text("Your homelab, one tap away")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Features list
                VStack(spacing: 16) {
                    ForEach(features, id: \.0) { icon, title, description in
                        FeatureRow(icon: icon, title: title, description: description)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA
                VStack(spacing: 16) {
                    Button {
                        showingSetup = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                            Text("Connect to Homepage")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background {
                            LinearGradient(
                                colors: [Color.blue, Color.indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .blue.opacity(0.4), radius: 12, y: 6)
                    }

                    Text("You can also add services manually later")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showingSetup) {
            ConnectionSetupView()
        }
        .onAppear {
            animationPhase = 1
        }
    }

    private var orbitingIcons: [String] {
        ["play.tv.fill", "chart.bar.fill", "house.fill", "server.rack"]
    }

    private var orbitingColors: [Color] {
        [.purple, .green, .orange, .cyan]
    }

    private func orbitOffset(for index: Int) -> CGSize {
        let angle = (Double(animationPhase) * 2 * .pi) + (Double(index) * .pi / 2)
        let radius: Double = 80
        return CGSize(
            width: Foundation.cos(angle) * radius,
            height: Foundation.sin(angle) * radius
        )
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.1))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

struct OnboardingBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.5
                        )
                    )
                    .frame(width: geo.size.width)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.2)
                    .blur(radius: 80)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.indigo.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.8, y: geo.size.height * 0.7)
                    .blur(radius: 60)
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Service.self, HomepageConnection.self, AppSettings.self], inMemory: true)
}

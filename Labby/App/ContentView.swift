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
    @Query private var allSettings: [AppSettings]

    @State private var selectedTab: Tab = .dashboard

    private var settings: AppSettings? {
        allSettings.first
    }

    private var colorSchemePreference: ColorScheme? {
        settings?.colorSchemePreference.colorScheme
    }

    private var shouldShowOnboarding: Bool {
        connections.isEmpty && !(settings?.hasCompletedOnboarding ?? false)
    }

    enum Tab: Hashable {
        case dashboard
        case browser
        case settings
        case search
    }

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingView()
            } else {
                MainTabView(selectedTab: $selectedTab)
                    .environment(\.selectedTab, $selectedTab)
            }
        }
        .preferredColorScheme(colorSchemePreference)
    }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
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
        .onAppear {
            // Restore trusted domains for SSL certificate handling
            SyncManager.shared.restoreTrustedDomains(modelContext: modelContext)
            // Restore previously open browser tabs
            TabManager.shared.restoreTabs(modelContext: modelContext)
        }
    }
}

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]
    @State private var showingSetup = false
    @State private var showingHomepageInfo = false

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
                    // Mascot image
                    Image("LabbyMascot")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .shadow(color: LabbyColors.primary(for: colorScheme).opacity(0.5), radius: 20, y: 10)

                    VStack(spacing: 8) {
                        Text("Labby")
                            .retroStyle(.largeTitle, weight: .black)

                        Text("Your homelab, one tap away")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Features list
                VStack(spacing: 16) {
                    ForEach(features, id: \.0) { icon, title, description in
                        if title == "Auto Sync" {
                            FeatureRow(
                                icon: icon,
                                title: title,
                                description: description,
                                showInfoButton: true,
                                onInfoTap: { showingHomepageInfo = true }
                            )
                        } else {
                            FeatureRow(icon: icon, title: title, description: description)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA
                VStack(spacing: 16) {
                    LabbyButton(title: "Connect to Homepage", icon: "link") {
                        showingSetup = true
                    }

                    LabbySecondaryButton(title: "or add services manually") {
                        skipOnboarding()
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showingSetup) {
            ConnectionSetupView()
        }
        .sheet(isPresented: $showingHomepageInfo) {
            HomepageInfoSheet()
        }
    }

    private func skipOnboarding() {
        if let settings = allSettings.first {
            settings.hasCompletedOnboarding = true
        } else {
            let newSettings = AppSettings(hasCompletedOnboarding: true)
            modelContext.insert(newSettings)
        }
        try? modelContext.save()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    var showInfoButton: Bool = false
    var onInfoTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var primaryColor: Color {
        LabbyColors.primary(for: colorScheme)
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(primaryColor)
                .frame(width: 44, height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(primaryColor.opacity(0.1))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .retroStyle(.subheadline, weight: .semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showInfoButton {
                Button {
                    onInfoTap?()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(primaryColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Sheet view for displaying Homepage information
struct HomepageInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("What is Homepage?")
                        .retroStyle(.title2, weight: .bold)

                    HomepageInfoView()

                    Text("Don't have Homepage yet? No problem! You can add services manually in Labby and set up Homepage later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct OnboardingBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var primaryColor: Color {
        LabbyColors.primary(for: colorScheme)
    }

    private var secondaryColor: Color {
        colorScheme == .dark ? LabbyColors.darkGradientEnd : LabbyColors.lightGradientStart
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [primaryColor.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.5
                        )
                    )
                    .frame(width: geo.size.width)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.2)
                    .blur(radius: 40)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [secondaryColor.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.8, y: geo.size.height * 0.7)
                    .blur(radius: 30)
            }
            .drawingGroup() // Rasterize to prevent expensive blur recalculation
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Service.self, HomepageConnection.self, AppSettings.self], inMemory: true)
}

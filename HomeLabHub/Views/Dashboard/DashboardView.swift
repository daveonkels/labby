import SwiftUI
import SwiftData

enum HealthFilter: Equatable {
    case online
    case offline
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Service.sortOrder) private var services: [Service]
    @Query private var connections: [HomepageConnection]

    @Binding var searchText: String
    @State private var isRefreshing = false
    @State private var healthFilter: HealthFilter? = nil

    private var isFilterActive: Bool {
        healthFilter != nil
    }

    /// Dashboard title from the connection name, or "Dashboard" as fallback
    private var dashboardTitle: String {
        connections.first?.name ?? "Dashboard"
    }

    init(searchText: Binding<String> = .constant("")) {
        _searchText = searchText
    }

    private var filteredServices: [Service] {
        var result = services

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply health filter
        if let filter = healthFilter {
            switch filter {
            case .online:
                result = result.filter { $0.isHealthy == true }
            case .offline:
                result = result.filter { $0.isHealthy == false }
            }
        }

        return result
    }

    private var groupedServices: [(String, [Service])] {
        let grouped = Dictionary(grouping: filteredServices) { $0.category ?? "Other" }
        return grouped.sorted { $0.key < $1.key }
    }

    private var healthStats: (online: Int, offline: Int) {
        let online = services.filter { $0.isHealthy == true }.count
        let offline = services.filter { $0.isHealthy == false || $0.isHealthy == nil }.count
        return (online, offline)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                        // Custom header when filter is active
                        HStack {
                            Text(dashboardTitle)
                                .font(.largeTitle.weight(.bold))

                            Spacer()

                            StatusSummaryCard(
                                online: healthStats.online,
                                offline: healthStats.offline,
                                selectedFilter: $healthFilter
                            )
                        }
                        .padding(.bottom, 8)
                        .opacity(isFilterActive ? 1 : 0)
                        .frame(height: isFilterActive ? nil : 0)
                        .clipped()
                        .id("top")

                        if services.isEmpty {
                            EmptyDashboardView()
                        } else {
                            // Show search results or grouped view
                            if !searchText.isEmpty || isFilterActive {
                                ServiceGridView(services: filteredServices)
                            } else {
                                ForEach(groupedServices, id: \.0) { category, categoryServices in
                                    Section {
                                        ServiceGridView(services: categoryServices)
                                    } header: {
                                        CategoryHeader(
                                            title: category,
                                            count: categoryServices.count,
                                            onlineCount: categoryServices.filter { $0.isHealthy == true }.count
                                        )
                                    }
                                }
                            }

                            // Status filter at the bottom (only when no filter active)
                            StatusSummaryCard(
                                online: healthStats.online,
                                offline: healthStats.offline,
                                selectedFilter: $healthFilter
                            )
                            .padding(.top, 16)
                            .opacity(isFilterActive ? 0 : 1)
                            .frame(height: isFilterActive ? 0 : nil)
                            .clipped()
                        }
                    }
                    .padding()
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFilterActive)
                }
                .background {
                    DashboardBackground()
                }
                .onChange(of: healthFilter) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
            .navigationTitle(isFilterActive ? "" : dashboardTitle)
            .navigationBarTitleDisplayMode(isFilterActive ? .inline : .large)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFilterActive)
            .refreshable {
                await refreshServices()
            }
            .task {
                // Start health monitoring when dashboard appears
                await HealthChecker.shared.startMonitoring(modelContext: modelContext)
            }
        }
    }

    private func refreshServices() async {
        isRefreshing = true
        await SyncManager.shared.syncAllConnections(modelContext: modelContext)
        // Run health checks after sync
        await HealthChecker.shared.checkAllServices(modelContext: modelContext)
        isRefreshing = false
    }
}

// MARK: - Status Summary Card

struct StatusSummaryCard: View {
    let online: Int
    let offline: Int
    @Binding var selectedFilter: HealthFilter?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            StatusPill(
                icon: "checkmark.circle.fill",
                count: online,
                color: .green,
                accessibilityLabel: "Online",
                isSelected: selectedFilter == .online
            ) {
                selectedFilter = selectedFilter == .online ? nil : .online
            }

            StatusPill(
                icon: "xmark.circle.fill",
                count: offline,
                color: .red,
                accessibilityLabel: "Offline",
                isSelected: selectedFilter == .offline
            ) {
                selectedFilter = selectedFilter == .offline ? nil : .offline
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.06), radius: 4, y: 2)
        }
        .accessibilityElement(children: .contain)
    }
}

struct StatusPill: View {
    let icon: String
    let count: Int
    let color: Color
    let accessibilityLabel: String
    var isSelected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)

                Text("\(count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(color.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(accessibilityLabel): \(count)")
        .accessibilityHint(isSelected ? "Tap to show all services" : "Tap to filter to \(accessibilityLabel.lowercased()) services")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Dashboard Background

struct DashboardBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query private var allSettings: [AppSettings]

    private var settings: AppSettings? {
        allSettings.first
    }

    private var gradientPreset: GradientPreset {
        settings?.gradientPreset ?? .default
    }

    private var intensity: Double {
        settings?.backgroundIntensity ?? 0.5
    }

    /// Calculates overlay opacity for custom images
    /// Higher intensity = less overlay = more visible background
    private var imageOverlayOpacity: Double {
        let baseOpacity = colorScheme == .dark ? 0.85 : 0.9
        return baseOpacity - (intensity * 0.5)
    }

    var body: some View {
        ZStack {
            // Base background color
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            // Custom image background if set
            if let imageData = settings?.backgroundImage,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                // Overlay for readability
                Color(.systemGroupedBackground)
                    .opacity(imageOverlayOpacity)
                    .ignoresSafeArea()
            } else {
                // Gradient based on selected preset
                GradientPresetBackground(preset: gradientPreset, intensity: intensity)
                    .ignoresSafeArea()
            }
        }
    }
}

struct GradientPresetBackground: View {
    let preset: GradientPreset
    var intensity: Double = 0.5

    /// Scales gradient opacity based on intensity
    /// At 0: scale by 0.4 (subtle)
    /// At 0.5: scale by 1.0 (normal)
    /// At 1.0: scale by 1.6 (vibrant)
    private var opacityScale: Double {
        0.4 + (intensity * 1.2)
    }

    var body: some View {
        if preset == .default {
            // Default subtle gradient orbs
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.green.opacity(0.15 * opacityScale), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.9, y: geo.size.height * 0.1)
                    .blur(radius: 60)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.1 * opacityScale), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.3
                        )
                    )
                    .frame(width: geo.size.width * 0.6)
                    .position(x: geo.size.width * 0.1, y: geo.size.height * 0.8)
                    .blur(radius: 50)
            }
        } else if preset.isRadial {
            GeometryReader { geo in
                RadialGradient(
                    colors: preset.colors.map { $0.opacity(0.25 * opacityScale) } + [Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(geo.size.width, geo.size.height) * 0.7
                )
            }
        } else {
            LinearGradient(
                colors: preset.colors.map { $0.opacity(0.3 * opacityScale) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct EmptyDashboardView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                // Pulsing rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                        .frame(width: CGFloat(80 + index * 30), height: CGFloat(80 + index * 30))
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0 : 0.6)
                        .animation(
                            .easeInOut(duration: 2)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.4),
                            value: isAnimating
                        )
                }

                // Center icon
                Image(systemName: "square.grid.2x2.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor.gradient)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5), value: isAnimating)
            }
            .frame(height: 140)

            VStack(spacing: 8) {
                Text("No Services Yet")
                    .font(.title2.weight(.semibold))

                Text("Add services manually or connect to your Homepage dashboard to sync automatically")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // CTA buttons
            VStack(spacing: 12) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Connect to Homepage", systemImage: "link")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                NavigationLink {
                    AddServiceView()
                } label: {
                    Label("Add Service Manually", systemImage: "plus.circle")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .onAppear {
            isAnimating = true
        }
    }
}

struct CategoryHeader: View {
    let title: String
    var count: Int = 0
    var onlineCount: Int = 0

    private var categoryIcon: String {
        switch title.lowercased() {
        case "media": return "play.tv.fill"
        case "downloads": return "arrow.down.circle.fill"
        case "automation": return "gearshape.2.fill"
        case "infrastructure": return "server.rack"
        case "monitoring": return "chart.bar.fill"
        case "network": return "network"
        case "storage": return "externaldrive.fill"
        default: return "folder.fill"
        }
    }

    private var categoryColor: Color {
        switch title.lowercased() {
        case "media": return .purple
        case "downloads": return .blue
        case "automation": return .orange
        case "infrastructure": return .indigo
        case "monitoring": return .green
        case "network": return .cyan
        case "storage": return .brown
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Category icon
            Image(systemName: categoryIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(categoryColor)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(categoryColor.opacity(0.15))
                }

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            // Status badge
            if count > 0 {
                Text("\(onlineCount)/\(count)")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(onlineCount == count ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, -16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) category, \(onlineCount) of \(count) services online")
    }
}

struct ServiceGridView: View {
    let services: [Service]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(services, id: \.id) { service in
                ServiceCard(service: service)
            }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Service.self, HomepageConnection.self, AppSettings.self], inMemory: true)
}

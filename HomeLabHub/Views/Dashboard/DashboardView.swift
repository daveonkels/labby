import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Service.sortOrder) private var services: [Service]

    @State private var searchText = ""
    @State private var isRefreshing = false

    private var groupedServices: [(String, [Service])] {
        let filtered = searchText.isEmpty
            ? services
            : services.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

        let grouped = Dictionary(grouping: filtered) { $0.category ?? "Other" }
        return grouped.sorted { $0.key < $1.key }
    }

    private var healthStats: (online: Int, offline: Int, unknown: Int) {
        let online = services.filter { $0.isHealthy == true }.count
        let offline = services.filter { $0.isHealthy == false }.count
        let unknown = services.filter { $0.isHealthy == nil }.count
        return (online, offline, unknown)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                    if services.isEmpty {
                        EmptyDashboardView()
                    } else {
                        // Status summary card
                        StatusSummaryCard(
                            total: services.count,
                            online: healthStats.online,
                            offline: healthStats.offline,
                            unknown: healthStats.unknown
                        )
                        .padding(.horizontal, 4)

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
                }
                .padding()
            }
            .background {
                DashboardBackground()
            }
            .navigationTitle("Dashboard")
            .searchable(text: $searchText, prompt: "Search services")
            .refreshable {
                await refreshServices()
            }
        }
    }

    private func refreshServices() async {
        isRefreshing = true
        await SyncManager.shared.syncAllConnections(modelContext: modelContext)
        isRefreshing = false
    }
}

// MARK: - Status Summary Card

struct StatusSummaryCard: View {
    let total: Int
    let online: Int
    let offline: Int
    let unknown: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            StatusPill(
                icon: "checkmark.circle.fill",
                count: online,
                label: "Online",
                color: .green
            )

            Divider()
                .frame(height: 32)
                .padding(.horizontal)

            StatusPill(
                icon: "xmark.circle.fill",
                count: offline,
                label: "Offline",
                color: .red
            )

            Divider()
                .frame(height: 32)
                .padding(.horizontal)

            StatusPill(
                icon: "questionmark.circle.fill",
                count: unknown,
                label: "Unknown",
                color: .orange
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Service status: \(online) online, \(offline) offline, \(unknown) unknown")
    }
}

struct StatusPill: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)

                Text("\(count)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Dashboard Background

struct DashboardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            // Subtle gradient orbs
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.green.opacity(0.15), Color.clear],
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
                            colors: [Color.blue.opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.3
                        )
                    )
                    .frame(width: geo.size.width * 0.6)
                    .position(x: geo.size.width * 0.1, y: geo.size.height * 0.8)
                    .blur(radius: 50)
            }
            .ignoresSafeArea()
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
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial)
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
        .modelContainer(for: [Service.self, HomepageConnection.self], inMemory: true)
}

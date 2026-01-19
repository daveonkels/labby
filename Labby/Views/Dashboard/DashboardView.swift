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
    @Query(sort: \Bookmark.sortOrder) private var bookmarks: [Bookmark]
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

    /// Bookmarks grouped by category
    private var groupedBookmarks: [(String, [Bookmark])] {
        let grouped = Dictionary(grouping: bookmarks) { $0.category ?? "Bookmarks" }
        return grouped.sorted { $0.key < $1.key }
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
            dashboardContent
                .navigationTitle(isFilterActive ? "" : dashboardTitle)
                .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private var dashboardContent: some View {
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
                            ServiceGridView(services: filteredServices, isFirstSection: true)
                        } else {
                            ForEach(Array(groupedServices.enumerated()), id: \.element.0) { sectionIndex, group in
                                let (category, categoryServices) = group
                                Section {
                                    ServiceGridView(services: categoryServices, isFirstSection: sectionIndex == 0)
                                } header: {
                                    CategoryHeader(
                                        title: category,
                                        count: categoryServices.count,
                                        onlineCount: categoryServices.filter { $0.isHealthy == true }.count
                                    )
                                }
                            }
                        }

                        // Bookmarks section
                        if !bookmarks.isEmpty && !isFilterActive && searchText.isEmpty {
                            BookmarksSection(groupedBookmarks: groupedBookmarks)
                                .padding(.top, 24)
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
    }

    private func refreshServices() async {
        isRefreshing = true
        await SyncManager.shared.syncAllConnections(modelContext: modelContext)
        // Run health checks after sync
        await HealthChecker.shared.checkAllServices(modelContext: modelContext)
        // Force icon reload after sync
        NotificationCenter.default.post(name: .reloadServiceIcons, object: nil)
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
                color: LabbyColors.primary(for: colorScheme),
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

    @Environment(\.colorScheme) private var colorScheme

    private var primaryColor: Color {
        LabbyColors.primary(for: colorScheme)
    }

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
                            colors: [primaryColor.opacity(0.15 * opacityScale), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.9, y: geo.size.height * 0.1)
                    .blur(radius: 30)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [primaryColor.opacity(0.1 * opacityScale), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.3
                        )
                    )
                    .frame(width: geo.size.width * 0.6)
                    .position(x: geo.size.width * 0.1, y: geo.size.height * 0.8)
                    .blur(radius: 25)
            }
            .drawingGroup() // Rasterize to prevent expensive blur recalculation
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
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    private var primaryColor: Color {
        LabbyColors.primary(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                // Pulsing rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(primaryColor.opacity(0.3), lineWidth: 2)
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
                    .foregroundStyle(primaryColor.gradient)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5), value: isAnimating)
            }
            .frame(height: 140)

            VStack(spacing: 8) {
                Text("No Services Yet")
                    .retroStyle(.title2, weight: .bold)

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
                        .retroStyle(.headline, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(primaryColor)
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                NavigationLink {
                    AddServiceView()
                } label: {
                    Label("Add Service Manually", systemImage: "plus.circle")
                        .retroStyle(.subheadline, weight: .medium)
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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var showIconPicker = false
    @State private var savedIconName: String?
    @State private var hasLoadedPreference = false

    /// Whether the user has explicitly chosen "no icon"
    private var isIconHidden: Bool {
        hasLoadedPreference && savedIconName == ""
    }

    /// Returns the icon to display: user preference or fallback to default
    private var displayIcon: String? {
        guard !isIconHidden else { return nil }
        if let saved = savedIconName, !saved.isEmpty {
            return saved
        }
        return defaultCategoryIcon
    }

    /// Default icon based on category name (fallback when no preference set)
    private var defaultCategoryIcon: String {
        switch title.lowercased() {
        case "media": return "play.tv.fill"
        case "downloads": return "arrow.down.circle.fill"
        case "automation": return "gearshape.2.fill"
        case "infrastructure": return "server.rack"
        case "monitoring": return "chart.bar.fill"
        case "network": return "network"
        case "storage": return "externaldrive.fill"
        case "productivity": return "doc.text.fill"
        case "utilities": return "wrench.and.screwdriver.fill"
        case "security": return "lock.shield.fill"
        case "development": return "hammer.fill"
        case "home": return "house.fill"
        case "finance": return "creditcard.fill"
        case "communication": return "bubble.left.and.bubble.right.fill"
        case "gaming": return "gamecontroller.fill"
        default: return "square.grid.2x2.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Category icon (tappable to change) - hidden if user chose "no icon"
            if let icon = displayIcon {
                Button {
                    showIconPicker = true
                } label: {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.15))
                        }
                }
                .buttonStyle(.plain)
            }

            // Title (tappable to change icon when icon is hidden)
            if isIconHidden {
                Button {
                    showIconPicker = true
                } label: {
                    Text(title)
                        .retroStyle(.headline, weight: .semibold)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            } else {
                Text(title)
                    .retroStyle(.headline, weight: .semibold)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Status badge
            if count > 0 {
                Text("\(onlineCount)/\(count)")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(onlineCount == count ? LabbyColors.primary(for: colorScheme) : .secondary)
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
        .accessibilityHint(isIconHidden ? "Tap title to add icon" : "Tap icon to change")
        .onAppear {
            loadSavedIcon()
        }
        .sheet(isPresented: $showIconPicker) {
            CategoryIconPicker(
                categoryName: title,
                currentIcon: displayIcon,
                onSelect: saveIconPreference
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func loadSavedIcon() {
        let categoryKey = title.lowercased()
        let descriptor = FetchDescriptor<CategoryIconPreference>(
            predicate: #Predicate { $0.categoryName == categoryKey }
        )
        if let preference = try? modelContext.fetch(descriptor).first {
            savedIconName = preference.iconName
        }
        hasLoadedPreference = true
    }

    private func saveIconPreference(_ iconName: String?) {
        let categoryKey = title.lowercased()
        // Use empty string to represent "no icon" choice
        let iconToSave = iconName ?? ""

        // Check if preference already exists
        let descriptor = FetchDescriptor<CategoryIconPreference>(
            predicate: #Predicate { $0.categoryName == categoryKey }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            // Update existing preference
            existing.iconName = iconToSave
            existing.updatedAt = Date()
        } else {
            // Create new preference
            let preference = CategoryIconPreference(categoryName: categoryKey, iconName: iconToSave)
            modelContext.insert(preference)
        }

        // Update local state
        savedIconName = iconToSave

        // Save context
        try? modelContext.save()
    }
}

struct ServiceGridView: View {
    let services: [Service]
    var isFirstSection: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(services.enumerated()), id: \.element.id) { index, service in
                ServiceCard(service: service, isFirstCard: isFirstSection && index == 0)
            }
        }
    }
}

// MARK: - Bookmarks Section

struct BookmarksSection: View {
    let groupedBookmarks: [(String, [Bookmark])]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main bookmarks header
            BookmarksSectionHeader()

            ForEach(groupedBookmarks, id: \.0) { category, categoryBookmarks in
                VStack(alignment: .leading, spacing: 10) {
                    // Category header
                    Text(category)
                        .retroStyle(.subheadline, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    // Bookmark pills - flowing layout
                    FlowLayout(spacing: 8) {
                        ForEach(categoryBookmarks, id: \.id) { bookmark in
                            BookmarkPill(bookmark: bookmark)
                        }
                    }
                }
            }
        }
    }
}

struct BookmarksSectionHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bookmark.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                }

            Text("Bookmarks")
                .retroStyle(.headline, weight: .semibold)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, -16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bookmarks section")
    }
}

struct BookmarkPill: View {
    let bookmark: Bookmark
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = bookmark.url {
                openURL(url)
            }
        } label: {
            Text(bookmark.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(bookmark.name)
        .accessibilityHint("Opens \(bookmark.urlString)")
    }
}

// MARK: - Flow Layout for Bookmarks

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, containerWidth: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? result.width, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, containerWidth: bounds.width)

        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: point, anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, containerWidth: CGFloat) -> (width: CGFloat, height: CGFloat, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > containerWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX - spacing)
        }

        return (maxWidth, currentY + lineHeight, positions)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Service.self, HomepageConnection.self, AppSettings.self, Bookmark.self], inMemory: true)
}

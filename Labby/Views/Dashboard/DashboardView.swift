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
    @Query private var appSettingsArray: [AppSettings]
    private var appSettings: AppSettings? { appSettingsArray.first }

    @Binding var searchText: String
    @State private var isRefreshing = false
    @State private var healthFilter: HealthFilter? = nil
    @State private var isEditMode = false
    @State private var editingService: Service? = nil
    @State private var isReorderDragActive = false
    // Edit mode drag-to-reorder state
    @State private var editOrderedServices: [Service] = []
    @State private var draggingServiceID: UUID?
    @State private var editDragOffset: CGSize = .zero
    @State private var editDragStartFrame: CGRect?
    @State private var editServiceFrames: [UUID: CGRect] = [:]
    @State private var editLastReorderDate: Date?
    @State private var editPressServiceID: UUID?
    @State private var editCurrentDragTranslation: CGSize = .zero
    @State private var editDragActivationOffset: CGSize = .zero
    private let debugLogger = DebugLogger.shared

    /// Whether there are any services that can be edited
    private var hasServices: Bool {
        !services.isEmpty
    }

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

    /// Groups for edit mode (derived from the mutable editOrderedServices state)
    private var editGroupedServices: [(String, [Service])] {
        let grouped = Dictionary(grouping: editOrderedServices) { $0.category ?? "Other" }
        return grouped.sorted { $0.key < $1.key }
    }

    private let editColumns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

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
                .onAppear {
                    debugLogger.debug("DashboardView appeared", category: "Dashboard")
                }
                .onDisappear {
                    debugLogger.debug("DashboardView disappeared", category: "Dashboard")
                }
                #if DEBUG
                .overlay {
                    HitTestProbe(isEditMode: isEditMode)
                        .allowsHitTesting(false) // CRITICAL: must not block SwiftUI gestures
                }
                #endif
                .toolbar {
                    if hasServices {
                        ToolbarItem(placement: .primaryAction) {
                            Button(isEditMode ? "Done" : "Edit") {
                                debugLogger.debug("Edit button tapped. Current isEditMode: \(isEditMode)", category: "Dashboard")
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isEditMode.toggle()
                                }
                                debugLogger.debug("Edit button toggled. New isEditMode: \(isEditMode)", category: "Dashboard")
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFilterActive)
                .refreshable {
                    await refreshServices()
                }
                .task {
                    // Start health monitoring when dashboard appears
                    HealthChecker.shared.startMonitoring(modelContext: modelContext)
                }
                .sheet(item: $editingService) { service in
                    ServiceCategoryEditor(service: service, onDismiss: {
                        debugLogger.debug("Category editor dismissed for \(service.name)", category: "Dashboard")
                        editingService = nil
                    })
                    .presentationDetents([.medium])
                }
                .onChange(of: isEditMode) { _, newValue in
                    debugLogger.debug("isEditMode changed to \(newValue)", category: "Dashboard")
                    debugLogger.dumpWindowHierarchy(reason: "isEditMode=\(newValue)")
                    if newValue {
                        editOrderedServices = buildEditOrderedServices()
                    } else {
                        // Clean up drag state
                        draggingServiceID = nil
                        editDragOffset = .zero
                        editDragStartFrame = nil
                        editPressServiceID = nil
                        editCurrentDragTranslation = .zero
                        editDragActivationOffset = .zero
                        isReorderDragActive = false
                    }
                }
        }
    }

    @ViewBuilder
    private var dashboardContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                    // Custom header when filter is active
                    if isFilterActive {
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
                        .id("top")
                    }

                    if services.isEmpty {
                        EmptyDashboardView()
                    } else {
                        // Show search results or grouped view
                        if !searchText.isEmpty || isFilterActive {
                            ServiceGridView(
                                services: filteredServices,
                                isFirstSection: true,
                                isEditMode: isEditMode,
                                category: nil,
                                onEditCategory: { service in
                                    editingService = service
                                }
                            )
                        } else if isEditMode {
                            // Edit mode: sectioned view with cross-category drag reordering
                            // Long press on each card activates drag; container tracks movement.
                            // Scroll works normally until a card is picked up.
                            VStack(spacing: 16) {
                                ForEach(editGroupedServices, id: \.0) { category, categoryServices in
                                    // Section header (non-interactive in edit mode)
                                    HStack(spacing: 10) {
                                        Text(category)
                                            .retroStyle(.headline, weight: .semibold)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Text("\(categoryServices.count)")
                                            .font(.caption.weight(.medium).monospacedDigit())
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background {
                                                Capsule()
                                                    .fill(Color.secondary.opacity(0.1))
                                            }
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 4)

                                    // Service cards grid
                                    LazyVGrid(columns: editColumns, spacing: 16) {
                                        ForEach(categoryServices) { service in
                                            let isDragging = service.id == draggingServiceID
                                            ServiceCard(
                                                service: service,
                                                isFirstCard: false,
                                                isEditMode: true,
                                                isDragging: isDragging,
                                                onEditCategory: { s in editingService = s }
                                            )
                                            .opacity(isDragging ? 0.001 : 1)
                                            .zIndex(isDragging ? 1 : 0)
                                            // Press feedback: slight scale-down while holding
                                            .scaleEffect(editPressServiceID == service.id && !isDragging ? 0.96 : 1.0)
                                            .animation(.easeInOut(duration: 0.1), value: editPressServiceID)
                                            .background(
                                                GeometryReader { geo in
                                                    Color.clear.preference(
                                                        key: ItemFramePreferenceKey<UUID>.self,
                                                        value: [service.id: geo.frame(in: .named("editGrid"))]
                                                    )
                                                }
                                            )
                                            // Long press on each card — knows which card, lifts immediately
                                            .onLongPressGesture(minimumDuration: 0.15, pressing: { isPressing in
                                                editPressServiceID = isPressing ? service.id : nil
                                            }) {
                                                editPressServiceID = nil
                                                editDragStartFrame = editServiceFrames[service.id]
                                                editDragActivationOffset = editCurrentDragTranslation
                                                HapticManager.impact(.medium)
                                                isReorderDragActive = true
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    draggingServiceID = service.id
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .coordinateSpace(name: "editGrid")
                            .onPreferenceChange(ItemFramePreferenceKey<UUID>.self) { frames in
                                editServiceFrames = frames
                            }
                            // Track finger movement — simultaneous so scroll still works
                            .simultaneousGesture(editDragTrackingGesture)
                            .overlay(alignment: .topLeading) {
                                editDragPreview
                            }
                        } else {
                            ForEach(Array(groupedServices.enumerated()), id: \.element.0) { sectionIndex, group in
                                let (category, categoryServices) = group
                                let isCollapsed = Binding(
                                    get: { appSettings?.collapsedCategories.contains(category.lowercased()) ?? false },
                                    set: { _ in appSettings?.toggleCategoryCollapsed(category.lowercased()) }
                                )
                                Section {
                                    if !isCollapsed.wrappedValue {
                                        ServiceGridView(
                                            services: categoryServices,
                                            isFirstSection: sectionIndex == 0,
                                            isEditMode: isEditMode,
                                            category: category,
                                            onEditCategory: { service in
                                                editingService = service
                                            }
                                        )
                                    }
                                } header: {
                                    CategoryHeader(
                                        title: category,
                                        count: categoryServices.count,
                                        onlineCount: categoryServices.filter { $0.isHealthy == true }.count,
                                        isCollapsed: isCollapsed
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
            .scrollDisabled(isReorderDragActive)
            .onPreferenceChange(ReorderDragActiveKey.self) { value in
                if value != isReorderDragActive {
                    debugLogger.debug("ScrollView: scrollDisabled changing to \(value)", category: "Reorder")
                    isReorderDragActive = value
                }
            }
            .background {
                DashboardBackground()
            }
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        debugLogger.debug("Dashboard tap received", category: "Dashboard")
                    }
            )
            .coordinateSpace(name: "dashboardGrid")
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

    // MARK: - Edit Mode Reordering

    /// Build flat ordered list matching visual layout: sorted by category (alpha), then sortOrder within each.
    private func buildEditOrderedServices() -> [Service] {
        let grouped = Dictionary(grouping: Array(services)) { $0.category ?? "Other" }
        return grouped.sorted { $0.key < $1.key }
            .flatMap { $0.value }
    }

    /// Tracks finger movement for drag reorder. Runs simultaneously with scroll —
    /// only acts when `draggingServiceID` is set (by the per-card long press).
    private var editDragTrackingGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("editGrid"))
            .onChanged { drag in
                editCurrentDragTranslation = drag.translation
                if draggingServiceID != nil {
                    editDragOffset = CGSize(
                        width: drag.translation.width - editDragActivationOffset.width,
                        height: drag.translation.height - editDragActivationOffset.height
                    )
                    checkForEditReorder()
                }
            }
            .onEnded { _ in
                let wasActive = draggingServiceID != nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    draggingServiceID = nil
                    editDragOffset = .zero
                    editDragStartFrame = nil
                }
                editCurrentDragTranslation = .zero
                editDragActivationOffset = .zero
                isReorderDragActive = false
                editLastReorderDate = nil
                editPressServiceID = nil
                if wasActive {
                    persistEditReorder()
                }
            }
    }

    @ViewBuilder
    private var editDragPreview: some View {
        if let draggedID = draggingServiceID,
           let service = editOrderedServices.first(where: { $0.id == draggedID }),
           let startFrame = editDragStartFrame {
            ServiceCard(
                service: service,
                isFirstCard: false,
                isEditMode: true,
                isDragging: true,
                onEditCategory: nil
            )
            .frame(width: startFrame.width, height: startFrame.height)
            .scaleEffect(1.05)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            .offset(
                x: startFrame.minX + editDragOffset.width,
                y: startFrame.minY + editDragOffset.height
            )
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func editServiceAt(point: CGPoint) -> UUID? {
        for (id, frame) in editServiceFrames {
            if frame.contains(point) { return id }
        }
        return nil
    }

    private func checkForEditReorder() {
        guard let draggedID = draggingServiceID,
              let startFrame = editDragStartFrame else { return }

        // Debounce to prevent oscillation
        if let lastReorder = editLastReorderDate,
           Date().timeIntervalSince(lastReorder) < 0.2 { return }

        let dragCenter = CGPoint(
            x: startFrame.midX + editDragOffset.width,
            y: startFrame.midY + editDragOffset.height
        )

        // Phase 1: Exact hit test
        var targetID: UUID?
        var insertAfter = false
        for (id, frame) in editServiceFrames {
            guard id != draggedID else { continue }
            if frame.contains(dragCenter) {
                targetID = id
                break
            }
        }

        // Phase 2: Nearest card in same row (handles empty grid slots)
        if targetID == nil {
            var bestDistance: CGFloat = .infinity
            for (id, frame) in editServiceFrames {
                guard id != draggedID else { continue }
                // Check if drag is roughly in the same row
                if abs(dragCenter.y - frame.midY) < frame.height * 0.75 {
                    let dist = abs(dragCenter.x - frame.midX)
                    if dist < bestDistance {
                        bestDistance = dist
                        targetID = id
                        insertAfter = dragCenter.x > frame.midX
                    }
                }
            }
        }

        guard let targetID = targetID,
              let sourceIndex = editOrderedServices.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = editOrderedServices.firstIndex(where: { $0.id == targetID }) else { return }

        let targetCategory = editOrderedServices[targetIndex].category ?? "Other"

        editLastReorderDate = Date()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let movedService = editOrderedServices.remove(at: sourceIndex)
            var idx = targetIndex
            // When inserting after (empty slot to the right), adjust for removal shift
            if insertAfter && sourceIndex > targetIndex {
                idx = targetIndex + 1
            }
            idx = min(idx, editOrderedServices.count)
            editOrderedServices.insert(movedService, at: idx)
            if movedService.category != targetCategory {
                movedService.category = targetCategory
                debugLogger.debug("Service '\(movedService.name)' category → '\(targetCategory)'", category: "Reorder")
            }
        }
        HapticManager.selection()
    }

    private func persistEditReorder() {
        for (index, service) in editOrderedServices.enumerated() {
            service.sortOrder = index
        }
        try? modelContext.save()
        debugLogger.debug("Persisted edit reorder: \(editOrderedServices.count) services", category: "Reorder")
    }
}

// MARK: - Status Summary Card

#if DEBUG
struct HitTestProbe: UIViewRepresentable {
    let isEditMode: Bool

    func makeUIView(context: Context) -> HitTestLoggingView {
        let view = HitTestLoggingView()
        view.isUserInteractionEnabled = true
        view.backgroundColor = .clear
        view.isEditMode = isEditMode
        return view
    }

    func updateUIView(_ uiView: HitTestLoggingView, context: Context) {
        uiView.isEditMode = isEditMode
    }
}

final class HitTestLoggingView: UIView {
    var isEditMode: Bool = false

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        DebugLogger.shared.debug("HitTestProbe hit at (\(Int(point.x)), \(Int(point.y))) editMode=\(isEditMode)", category: "HitTest")
        return nil
    }
}
#endif

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
                if #available(iOS 17.0, *) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.largeTitle)
                        .foregroundStyle(primaryColor.gradient)
                        .symbolEffect(.bounce, options: .repeating.speed(0.5), value: isAnimating)
                } else {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.largeTitle)
                        .foregroundStyle(primaryColor.gradient)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                }
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
                    AddServiceView(showHomepageHint: true)
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
    @Binding var isCollapsed: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var showIconPicker = false
    @State private var savedIconName: String?
    @State private var hasLoadedPreference = false

    /// Whether the user has explicitly chosen "no icon"
    private var isIconHidden: Bool {
        hasLoadedPreference && savedIconName == ""
    }

    /// Icon type for rendering
    enum IconType {
        case sfSymbol(String)
        case emoji(String)
    }

    /// Returns the icon to display: user preference or fallback to default
    private var displayIcon: IconType? {
        guard !isIconHidden else { return nil }
        if let saved = savedIconName, !saved.isEmpty {
            // Check if it's an emoji
            if saved.hasPrefix("emoji:") {
                let emojiName = String(saved.dropFirst(6))
                if let character = CategoryIconPicker.emoji(for: emojiName) {
                    return .emoji(character)
                }
                // Fallback if emoji not found
                return .sfSymbol(defaultCategoryIcon)
            }
            return .sfSymbol(saved)
        }
        return .sfSymbol(defaultCategoryIcon)
    }

    /// Raw icon value for passing to picker (includes emoji: prefix if applicable)
    private var rawIconValue: String? {
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
                    Group {
                        switch icon {
                        case .sfSymbol(let name):
                            Image(systemName: name)
                                .font(.caption.weight(.semibold))
                        case .emoji(let character):
                            Text(character)
                                .font(.system(size: 14))
                        }
                    }
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

            // Collapse/expand chevron
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isCollapsed ? 0 : 90))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            DebugLogger.shared.debug("CategoryHeader TAP: '\(title)' isCollapsed=\(isCollapsed) → toggling", category: "CategoryHeader")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isCollapsed.toggle()
            }
        }
        .compatibleGlassEffect(GlassStyle.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, -16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) category, \(onlineCount) of \(count) services online, \(isCollapsed ? "collapsed" : "expanded")")
        .accessibilityHint("Tap to \(isCollapsed ? "expand" : "collapse"). \(isIconHidden ? "Tap title to add icon" : "Tap icon to change")")
        .onAppear {
            loadSavedIcon()
        }
        .sheet(isPresented: $showIconPicker) {
            CategoryIconPicker(
                categoryName: title,
                currentIcon: rawIconValue,
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
    var isEditMode: Bool = false
    var category: String? = nil
    var onEditCategory: ((Service) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var orderedServices: [Service] = []

    /// Adaptive grid that maintains roughly square cards
    /// - Portrait: 2 columns (~160-190pt each)
    /// - Landscape: 4+ columns (~160-200pt each)
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        Group {
            if isEditMode && category != nil {
                reorderableContent
            } else {
                normalContent
            }
        }
        .onChange(of: isEditMode) { _, newValue in
            DebugLogger.shared.debug("ServiceGridView: isEditMode changed to \(newValue), category=\(category ?? "nil"), services=\(services.count)", category: "ServiceGrid")
            if newValue {
                orderedServices = services
            }
        }
        .onAppear {
            DebugLogger.shared.debug("ServiceGridView appeared: isEditMode=\(isEditMode), category=\(category ?? "nil"), services=\(services.count), using \(isEditMode && category != nil ? "ReorderableGrid" : "normalContent")", category: "ServiceGrid")
            if isEditMode {
                orderedServices = services
            }
        }
    }

    @ViewBuilder
    private var reorderableContent: some View {
        ReorderableGrid(
            items: $orderedServices,
            columns: columns,
            spacing: 16,
            onReorder: { item, targetIndex in
                handleReorder(item: item, targetIndex: targetIndex)
            },
            onDragEnd: {
                persistReorder()
            }
        ) { service, isDragging in
            ServiceCard(
                service: service,
                isFirstCard: false,
                isEditMode: true,
                isDragging: isDragging,
                onEditCategory: onEditCategory
            )
        }
    }

    @ViewBuilder
    private var normalContent: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(services) { service in
                ServiceCard(
                    service: service,
                    isFirstCard: isFirstSection && services.first?.id == service.id,
                    isEditMode: isEditMode,
                    onEditCategory: onEditCategory
                )
            }
        }
    }

    private func handleReorder(item: Service, targetIndex: Int) {
        guard let currentIndex = orderedServices.firstIndex(where: { $0.id == item.id }) else { return }
        guard currentIndex != targetIndex else { return }

        let movedItem = orderedServices.remove(at: currentIndex)
        let insertIndex = min(targetIndex, orderedServices.count)
        orderedServices.insert(movedItem, at: insertIndex)
    }

    private func persistReorder() {
        for (index, service) in orderedServices.enumerated() {
            service.sortOrder = index
        }
        try? modelContext.save()
    }
}

struct AddServiceCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddService = false

    var body: some View {
        Button {
            showingAddService = true
        } label: {
            VStack(spacing: 16) {
                // Plus icon in circle
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                Text("Add Service")
                    .retroStyle(.subheadline, weight: .medium)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingAddService) {
            AddServiceView(showHomepageHint: true)
        }
        .accessibilityLabel("Add new service")
        .accessibilityHint("Opens form to add a new manual service")
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
        .compatibleGlassEffect(GlassStyle.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

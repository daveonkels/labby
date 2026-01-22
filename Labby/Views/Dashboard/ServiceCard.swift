import SwiftUI
import SwiftData
import UIKit

struct ServiceCard: View {
    let service: Service
    var isFirstCard: Bool = false
    var isEditMode: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.selectedTab) private var selectedTab
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]
    @State private var tabManager = TabManager.shared
    @State private var showOpenedToast = false
    @State private var showCloseTabPopover = false
    @State private var showLongPressHint = false
    @State private var didLongPress = false
    @State private var showDeleteAlert = false

    /// Whether this card can be deleted (only manual services in edit mode)
    private var canDelete: Bool {
        isEditMode && service.isManuallyAdded
    }

    private var settings: AppSettings? { allSettings.first }

    private var hasValidURL: Bool {
        guard let url = service.url else { return false }
        return !service.urlString.isEmpty && url.scheme != nil
    }

    private var hasOpenTab: Bool {
        tabManager.tabs.contains { $0.service.id == service.id }
    }

    var body: some View {
        Button {
            openService()
        } label: {
            VStack(spacing: 16) {
                // Icon container
                Circle()
                    .fill(.clear)
                    .frame(width: 56, height: 56)
                    .overlay {
                        ServiceIcon(service: service)
                            .frame(width: 28, height: 28)
                    }
                    .glassEffect(.regular, in: Circle())

                // Name + Status
                VStack(spacing: 6) {
                    Text(service.name)
                        .retroStyle(.subheadline, weight: .semibold)
                        .lineLimit(1)
                        .foregroundStyle(hasValidURL ? .primary : .secondary)

                    // Status badge - only colored element
                    if hasValidURL {
                        HealthBadge(isHealthy: service.isHealthy)
                    } else {
                        Label("Widget", systemImage: "square.grid.2x2")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(hasValidURL ? 1.0 : 0.6)
            .overlay(alignment: .topLeading) {
                // Green dot indicator when tab is open
                if hasOpenTab && !isEditMode {
                    Circle()
                        .fill(LabbyColors.primary(for: colorScheme))
                        .frame(width: 10, height: 10)
                        .padding(12)
                }
            }
            .overlay(alignment: .topTrailing) {
                // Delete button in edit mode (manual services only)
                if canDelete {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, .red)
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay {
                // Dim synced services in edit mode
                if isEditMode && !service.isManuallyAdded {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.5))
                }
            }
        }
        .buttonStyle(ServiceCardButtonStyle())
        .disabled(!hasValidURL || (isEditMode && !service.isManuallyAdded))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    handleLongPress()
                }
        )
        .popover(isPresented: $showCloseTabPopover, arrowEdge: .top) {
            CloseServiceTabPopover(onClose: {
                showCloseTabPopover = false
                closeServiceTab()
            })
            .presentationCompactAdaptation(.popover)
        }
        .popover(isPresented: $showOpenedToast, arrowEdge: .top) {
            OpenedTabPopover()
                .presentationCompactAdaptation(.popover)
        }
        .popover(isPresented: $showLongPressHint, arrowEdge: .bottom) {
            LongPressHintView(onDismiss: dismissLongPressHint)
                .presentationCompactAdaptation(.popover)
        }
        .alert("Delete Service?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteService()
            }
        } message: {
            Text("Are you sure you want to delete \"\(service.name)\"?")
        }
        .onAppear {
            // Show long-press hint on first card if user hasn't seen it
            if isFirstCard && hasValidURL && settings?.hasSeenLongPressHint == false {
                Task {
                    // Brief delay so user sees the dashboard first
                    try? await Task.sleep(for: .seconds(1.5))
                    showLongPressHint = true
                }
            }
        }
        .accessibilityLabel("\(service.name) service")
        .accessibilityHint(hasValidURL ? (hasOpenTab ? "Double tap to open, long press to close tab" : "Double tap to open in browser, long press to open in background") : "No URL configured")
        .accessibilityValue(hasOpenTab ? "Tab open. " : "" + healthAccessibilityValue)
    }

    private func dismissLongPressHint() {
        showLongPressHint = false
        settings?.hasSeenLongPressHint = true
        try? modelContext.save()
    }

    private var healthAccessibilityValue: String {
        switch service.isHealthy {
        case .some(true): return "Online"
        case .some(false): return "Offline"
        case .none: return "Status unknown"
        }
    }

    private func openService() {
        // Skip if this was triggered by a long press
        if didLongPress {
            didLongPress = false
            return
        }
        guard hasValidURL else { return }
        let _ = TabManager.shared.openService(service)
        selectedTab.wrappedValue = .browser
    }

    private func handleLongPress() {
        guard hasValidURL else { return }

        // Mark that we did a long press to prevent button action from firing
        didLongPress = true

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        if hasOpenTab {
            // Tab already open - show close confirmation popover
            showCloseTabPopover = true
        } else {
            // No tab open - open in background
            openServiceInBackground()
        }
    }

    private func openServiceInBackground() {
        // Open tab without switching to browser view
        let _ = TabManager.shared.openService(service)

        // Show confirmation popover
        showOpenedToast = true

        // Auto-dismiss after user can see it
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showOpenedToast = false
        }
    }

    private func closeServiceTab() {
        if let tab = tabManager.tabs.first(where: { $0.service.id == service.id }) {
            tabManager.closeTab(tab)
        }
    }

    private func deleteService() {
        // Close any open tab first
        closeServiceTab()
        // Delete the service
        modelContext.delete(service)
    }
}

struct ServiceCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct ServiceIcon: View {
    let service: Service
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let sfSymbol = service.iconSFSymbol {
                Image(systemName: sfSymbol)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            } else if let iconURL = service.iconURL {
                ThemedAsyncImage(
                    originalURL: iconURL,
                    colorScheme: colorScheme
                )
            } else {
                DefaultServiceIcon()
            }
        }
        .accessibilityHidden(true)
    }
}

/// Loads an icon with automatic dark/light mode variant support
/// Tries themed variant first, falls back to original if not available
/// Includes automatic retry on failure and pull-to-refresh support
/// Handles SVG icons (like MDI) using native SwiftUI path rendering
struct ThemedAsyncImage: View {
    let originalURL: URL
    let colorScheme: ColorScheme

    @State private var useFallback = false
    @State private var retryCount = 0
    @State private var forceReloadToken = UUID()

    /// Whether this URL points to an SVG file
    private var isSVG: Bool {
        originalURL.pathExtension.lowercased() == "svg" ||
        originalURL.absoluteString.contains(".svg")
    }

    private var themedURL: URL {
        guard !useFallback else { return originalURL }
        return IconURLTransformer.themedURL(from: originalURL, for: colorScheme)
    }

    /// URL with cache-busting query param for retries
    private var cacheBreakingURL: URL {
        guard retryCount > 0,
              var components = URLComponents(url: themedURL, resolvingAgainstBaseURL: false) else {
            return themedURL
        }
        let existingItems = components.queryItems ?? []
        components.queryItems = existingItems + [URLQueryItem(name: "_r", value: "\(retryCount)")]
        return components.url ?? themedURL
    }

    var body: some View {
        Group {
            if isSVG {
                // Use native SVG rendering for SVG icons (like MDI)
                SVGIconView(url: cacheBreakingURL, tintColor: .primary)
            } else {
                // Use AsyncImage for raster images (PNG, WebP, etc.)
                AsyncImage(url: cacheBreakingURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        if !useFallback && themedURL != originalURL {
                            // Themed variant failed, try original
                            ProgressView()
                                .scaleEffect(0.8)
                                .onAppear { useFallback = true }
                        } else if retryCount < 2 {
                            // Retry up to 2 times with delay
                            ProgressView()
                                .scaleEffect(0.8)
                                .task {
                                    try? await Task.sleep(for: .seconds(1))
                                    retryCount += 1
                                }
                        } else {
                            DefaultServiceIcon()
                        }
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.8)
                    @unknown default:
                        DefaultServiceIcon()
                    }
                }
            }
        }
        .id(forceReloadToken) // Force reload when token changes
        .onChange(of: colorScheme) { _, _ in
            // Reset state when color scheme changes
            useFallback = false
            retryCount = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadServiceIcons)) { _ in
            // Force reload when pull-to-refresh triggers
            forceReloadToken = UUID()
            retryCount = 0
            useFallback = false
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when service icons should be reloaded (e.g., after pull-to-refresh)
    static let reloadServiceIcons = Notification.Name("reloadServiceIcons")
}

/// Transforms icon URLs to their dark/light mode variants
enum IconURLTransformer {
    /// Returns the appropriate themed URL for the given color scheme
    static func themedURL(from url: URL, for colorScheme: ColorScheme) -> URL {
        let urlString = url.absoluteString

        // Simple Icons: add /white for dark mode
        // Format: https://cdn.simpleicons.org/{icon} -> https://cdn.simpleicons.org/{icon}/white
        if urlString.contains("cdn.simpleicons.org") {
            if colorScheme == .dark && !urlString.contains("/white") {
                return URL(string: urlString + "/white") ?? url
            }
            return url
        }

        // Dashboard Icons & selfhst/icons: add -light suffix for dark mode
        // Format: .../png/{icon}.png -> .../png/{icon}-light.png
        if (urlString.contains("dashboard-icons") || urlString.contains("selfhst/icons@main")) && urlString.hasSuffix(".png") {
            // Don't transform if already has a variant suffix
            if urlString.contains("-light.png") || urlString.contains("-dark.png") {
                return url
            }

            if colorScheme == .dark {
                let baseURL = String(urlString.dropLast(4)) // Remove ".png"
                return URL(string: baseURL + "-light.png") ?? url
            }
            return url
        }

        // Other URLs: return as-is
        return url
    }
}

struct DefaultServiceIcon: View {
    var body: some View {
        Image(systemName: "app.fill")
            .font(.title2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
    }
}

struct HealthBadge: View {
    let isHealthy: Bool?

    @Environment(\.colorScheme) private var colorScheme

    private var statusColor: Color {
        switch isHealthy {
        case .some(true): return LabbyColors.primary(for: colorScheme)
        case .some(false): return .red
        case .none: return .orange
        }
    }

    private var statusText: String {
        switch isHealthy {
        case .some(true): return "Online"
        case .some(false): return "Offline"
        case .none: return "Checking"
        }
    }

    private var statusIcon: String {
        switch isHealthy {
        case .some(true): return "checkmark.circle.fill"
        case .some(false): return "xmark.circle.fill"
        case .none: return "questionmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption2)
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, options: .repeating, isActive: isHealthy == nil)

            Text(statusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(statusColor.opacity(0.15))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(statusText)")
    }
}

// Legacy support
struct HealthIndicator: View {
    let isHealthy: Bool?

    var body: some View {
        HealthBadge(isHealthy: isHealthy)
    }
}

// MARK: - Close Tab Popover

struct CloseServiceTabPopover: View {
    let onClose: () -> Void

    var body: some View {
        Button(role: .destructive, action: onClose) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                Text("Close Tab")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
    }
}

struct OpenedTabPopover: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
            Text("Opened")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .foregroundStyle(LabbyColors.primary(for: colorScheme))
    }
}

struct LongPressHintView: View {
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap")
                    .font(.title3)
                Text("Long-press to open in background")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(LabbyColors.primary(for: colorScheme))

            Button("Got it") {
                onDismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

#Preview {
    HStack {
        ServiceCard(service: .preview)
        ServiceCard(service: Service(
            name: "Jellyfin",
            urlString: "http://localhost:8096",
            iconSFSymbol: "film",
            category: "Media"
        ))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

import SwiftUI

struct ServiceCard: View {
    let service: Service

    @Environment(\.selectedTab) private var selectedTab

    private var hasValidURL: Bool {
        guard let url = service.url else { return false }
        return !service.urlString.isEmpty && url.scheme != nil
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
                        .font(.subheadline.weight(.semibold))
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
        }
        .buttonStyle(ServiceCardButtonStyle())
        .disabled(!hasValidURL)
        .accessibilityLabel("\(service.name) service")
        .accessibilityHint(hasValidURL ? "Double tap to open in browser" : "No URL configured")
        .accessibilityValue(healthAccessibilityValue)
    }

    private var healthAccessibilityValue: String {
        switch service.isHealthy {
        case .some(true): return "Online"
        case .some(false): return "Offline"
        case .none: return "Status unknown"
        }
    }

    private func openService() {
        guard hasValidURL else { return }
        let _ = TabManager.shared.openService(service)
        selectedTab.wrappedValue = .browser
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
struct ThemedAsyncImage: View {
    let originalURL: URL
    let colorScheme: ColorScheme

    @State private var useFallback = false

    private var themedURL: URL {
        guard !useFallback else { return originalURL }
        return IconURLTransformer.themedURL(from: originalURL, for: colorScheme)
    }

    var body: some View {
        AsyncImage(url: themedURL) { phase in
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
        .id(themedURL) // Force reload when URL changes
        .onChange(of: colorScheme) { _, _ in
            // Reset fallback state when color scheme changes
            useFallback = false
        }
    }
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

        // Dashboard Icons: add -light suffix for dark mode
        // Format: .../png/{icon}.png -> .../png/{icon}-light.png
        if urlString.contains("dashboard-icons") && urlString.hasSuffix(".png") {
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

    private var statusColor: Color {
        switch isHealthy {
        case .some(true): return .green
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

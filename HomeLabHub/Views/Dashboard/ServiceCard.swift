import SwiftUI

struct ServiceCard: View {
    let service: Service

    @Environment(\.selectedTab) private var selectedTab
    @Environment(\.colorScheme) private var colorScheme

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
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay {
                        ServiceIcon(service: service)
                            .frame(width: 28, height: 28)
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    }

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
            .background {
                ZStack {
                    // Base card
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Inner highlight
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.1 : 0.5),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 4)
            }
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

    var body: some View {
        Group {
            if let sfSymbol = service.iconSFSymbol {
                Image(systemName: sfSymbol)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            } else if let iconURL = service.iconURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.8)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        DefaultServiceIcon()
                    @unknown default:
                        DefaultServiceIcon()
                    }
                }
            } else {
                DefaultServiceIcon()
            }
        }
        .accessibilityHidden(true)
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

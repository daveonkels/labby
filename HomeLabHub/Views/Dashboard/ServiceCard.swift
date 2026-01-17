import SwiftUI

struct ServiceCard: View {
    let service: Service

    @Environment(\.selectedTab) private var selectedTab
    @State private var isPressed = false

    private var hasValidURL: Bool {
        guard let url = service.url else { return false }
        return !service.urlString.isEmpty && url.scheme != nil
    }

    var body: some View {
        Button {
            openService()
        } label: {
            VStack(spacing: 12) {
                // Icon
                ServiceIcon(service: service)
                    .frame(width: 48, height: 48)

                // Name
                Text(service.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(hasValidURL ? .primary : .secondary)

                // Health indicator or "No URL" badge
                if hasValidURL {
                    HealthIndicator(isHealthy: service.isHealthy)
                } else {
                    Text("Widget Only")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
            .opacity(hasValidURL ? 1.0 : 0.6)
        }
        .buttonStyle(ServiceCardButtonStyle())
        .disabled(!hasValidURL)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isPressed)
    }

    private func openService() {
        guard hasValidURL else { return }

        isPressed = true

        // Open tab and switch to browser
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
                    .font(.system(size: 28))
                    .foregroundStyle(.blue.gradient)
            } else if let iconURL = service.iconURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
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
    }
}

struct DefaultServiceIcon: View {
    var body: some View {
        Image(systemName: "app.fill")
            .font(.system(size: 28))
            .foregroundStyle(.gray.gradient)
    }
}

struct HealthIndicator: View {
    let isHealthy: Bool?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch isHealthy {
        case .some(true):
            return .green
        case .some(false):
            return .red
        case .none:
            return .gray
        }
    }

    private var statusText: String {
        switch isHealthy {
        case .some(true):
            return "Online"
        case .some(false):
            return "Offline"
        case .none:
            return "Unknown"
        }
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

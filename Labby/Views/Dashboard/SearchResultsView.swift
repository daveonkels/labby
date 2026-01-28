import SwiftUI
import SwiftData

struct SearchResultsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.selectedTab) private var selectedTab
    @Query(sort: \Service.sortOrder) private var services: [Service]
    @Binding var searchText: String

    private var filteredServices: [Service] {
        guard !searchText.isEmpty else { return [] }
        return services.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if searchText.isEmpty {
                EmptySearchView()
            } else if filteredServices.isEmpty {
                EmptySearchResultsView(searchText: searchText)
            } else {
                List(filteredServices) { service in
                    ServiceSearchRow(service: service)
                }
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search services")
    }
}

struct ServiceSearchRow: View {
    let service: Service
    @Environment(\.selectedTab) private var selectedTab
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            // Open in browser tab
            _ = TabManager.shared.openService(service)
            selectedTab.wrappedValue = .browser
        } label: {
            HStack(spacing: 12) {
                // Service icon with dark/light mode support
                Group {
                    if let sfSymbol = service.iconSFSymbol {
                        if sfSymbol.hasPrefix("emoji:") {
                            let emojiName = String(sfSymbol.dropFirst(6))
                            if let character = CategoryIconPicker.emoji(for: emojiName) {
                                Text(character)
                                    .font(.title3)
                            } else {
                                Image(systemName: iconForCategory(service.category))
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Image(systemName: sfSymbol)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    } else if let iconURL = service.iconURL {
                        ThemedAsyncImage(originalURL: iconURL, colorScheme: colorScheme)
                    } else {
                        Image(systemName: iconForCategory(service.category))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .retroStyle(.body, weight: .medium)
                        .foregroundStyle(.primary)

                    if let category = service.category {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Health indicator
                Circle()
                    .fill(service.isHealthy == true ? LabbyColors.primary(for: colorScheme) : Color.red)
                    .frame(width: 8, height: 8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconForCategory(_ category: String?) -> String {
        switch category?.lowercased() {
        case "media": return "play.tv.fill"
        case "downloads": return "arrow.down.circle.fill"
        case "automation": return "gearshape.2.fill"
        case "infrastructure": return "server.rack"
        case "monitoring": return "chart.bar.fill"
        case "network": return "network"
        case "storage": return "externaldrive.fill"
        default: return "square.grid.2x2"
        }
    }
}

// MARK: - Empty Search View

struct EmptySearchView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var primaryColor: Color {
        LabbyColors.primary(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(primaryColor.opacity(0.6))

            VStack(spacing: 8) {
                Text("Search Services")
                    .retroStyle(.title2, weight: .bold)

                Text("Type to search your homelab services")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty Search Results View

struct EmptySearchResultsView: View {
    let searchText: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Results")
                    .retroStyle(.title2, weight: .bold)

                Text("No services match \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        SearchResultsView(searchText: .constant(""))
    }
    .modelContainer(for: [Service.self, HomepageConnection.self], inMemory: true)
}

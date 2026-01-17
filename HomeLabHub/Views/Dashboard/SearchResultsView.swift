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
                ContentUnavailableView(
                    "Search Services",
                    systemImage: "magnifyingglass",
                    description: Text("Type to search your homelab services")
                )
            } else if filteredServices.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredServices) { service in
                    ServiceSearchRow(service: service)
                }
            }
        }
        .navigationTitle("Search")
        .searchable(text: $searchText, prompt: "Search services")
    }
}

struct ServiceSearchRow: View {
    let service: Service
    @Environment(\.selectedTab) private var selectedTab

    var body: some View {
        Button {
            // Open in browser tab
            _ = TabManager.shared.openService(service)
            selectedTab.wrappedValue = .browser
        } label: {
            HStack(spacing: 12) {
                // Service icon
                AsyncImage(url: service.iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure, .empty:
                        Image(systemName: iconForCategory(service.category))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    @unknown default:
                        Image(systemName: "square.grid.2x2")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .font(.body.weight(.medium))
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
                    .fill(service.isHealthy == true ? Color.green : Color.red)
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

#Preview {
    NavigationStack {
        SearchResultsView(searchText: .constant(""))
    }
    .modelContainer(for: [Service.self, HomepageConnection.self], inMemory: true)
}

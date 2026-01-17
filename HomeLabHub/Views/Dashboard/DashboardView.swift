import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
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

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                    if services.isEmpty {
                        EmptyDashboardView()
                    } else {
                        ForEach(groupedServices, id: \.0) { category, categoryServices in
                            Section {
                                ServiceGridView(services: categoryServices)
                            } header: {
                                CategoryHeader(title: category)
                            }
                        }
                    }
                }
                .padding()
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

struct EmptyDashboardView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Services")
                .font(.headline)

            Text("Add services manually or sync from Homepage")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

struct CategoryHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(.background)
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

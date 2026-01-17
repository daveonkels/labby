import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [HomepageConnection]

    @State private var showingAddConnection = false
    @State private var showingAddService = false

    var body: some View {
        NavigationStack {
            List {
                // Homepage Connections
                Section {
                    ForEach(connections) { connection in
                        ConnectionRow(connection: connection)
                    }
                    .onDelete(perform: deleteConnections)

                    Button {
                        showingAddConnection = true
                    } label: {
                        Label("Add Homepage Connection", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Homepage Connections")
                } footer: {
                    Text("Connect to your Homepage instance to sync services automatically.")
                }

                // Manual Services
                Section {
                    Button {
                        showingAddService = true
                    } label: {
                        Label("Add Service Manually", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Manual Services")
                } footer: {
                    Text("Add services that aren't in your Homepage config.")
                }

                // App Info
                Section {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                } header: {
                    Text("About")
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        clearAllData()
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                } header: {
                    Text("Data")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddConnection) {
                ConnectionSetupView()
            }
            .sheet(isPresented: $showingAddService) {
                AddServiceView()
            }
        }
    }

    private func deleteConnections(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(connections[index])
        }
    }

    private func clearAllData() {
        // TODO: Add confirmation dialog
        try? modelContext.delete(model: HomepageConnection.self)
        try? modelContext.delete(model: Service.self)
    }
}

struct ConnectionRow: View {
    let connection: HomepageConnection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(connection.name)
                .font(.body)

            Text(connection.baseURLString)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let lastSync = connection.lastSync {
                Text("Last synced: \(lastSync, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Service.self, HomepageConnection.self], inMemory: true)
}

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [HomepageConnection]
    @Query private var services: [Service]
    @Query private var allSettings: [AppSettings]

    @State private var showingAddConnection = false
    @State private var showingAddService = false
    @State private var showingClearDataAlert = false
    @State private var connectionToEdit: HomepageConnection?

    private var settings: AppSettings {
        if let existing = allSettings.first {
            return existing
        }
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        return newSettings
    }

    var body: some View {
        NavigationStack {
            List {
                // Homepage Connection
                Section {
                    if connections.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "link.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .frame(width: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("No Connection")
                                    .font(.subheadline.weight(.medium))
                                Text("Add your Homepage connection")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        Button {
                            showingAddConnection = true
                        } label: {
                            Label("Add Homepage Connection", systemImage: "plus.circle.fill")
                                .foregroundStyle(LabbyColors.primary(for: colorScheme))
                        }
                    } else {
                        ForEach(connections) { connection in
                            ConnectionRow(connection: connection)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(connection)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        connectionToEdit = connection
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(LabbyColors.primary(for: colorScheme))
                                }
                        }
                    }
                } header: {
                    RetroSectionHeader("Homepage Connection", icon: "link")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(connections.isEmpty
                             ? "Connect to your Homepage instance to sync services automatically."
                             : "Swipe to edit or delete.")

                        Link(destination: URL(string: "https://gethomepage.dev")!) {
                            Text("Learn more about Homepage")
                                .font(.caption)
                        }
                    }
                }

                // Manual Services
                Section {
                    Button {
                        showingAddService = true
                    } label: {
                        Label("Add Service Manually", systemImage: "plus.circle.fill")
                            .foregroundStyle(LabbyColors.primary(for: colorScheme))
                    }
                } header: {
                    RetroSectionHeader("Manual Services", icon: "square.grid.2x2")
                } footer: {
                    Text("Add services that aren't in your Homepage config.")
                }

                // Appearance
                Section {
                    Picker(selection: Binding(
                        get: { settings.colorSchemePreference },
                        set: { newValue in
                            settings.colorSchemePreference = newValue
                            try? modelContext.save()
                        }
                    )) {
                        ForEach(ColorSchemePreference.allCases, id: \.self) { preference in
                            Text(preference.displayName).tag(preference)
                        }
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }

                    NavigationLink {
                        BackgroundSettingsView()
                    } label: {
                        Label("Dashboard Background", systemImage: "photo.artframe")
                    }
                } header: {
                    RetroSectionHeader("Appearance", icon: "paintbrush")
                }

                // Stats
                if !services.isEmpty {
                    Section {
                        LabeledContent {
                            Text("\(services.count)")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Total Services", systemImage: "square.grid.2x2")
                        }

                        LabeledContent {
                            Text("\(services.filter { $0.isHealthy == true }.count)")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(LabbyColors.primary(for: colorScheme))
                        } label: {
                            Label("Online", systemImage: "checkmark.circle")
                        }

                        LabeledContent {
                            Text("\(services.filter { $0.isManuallyAdded }.count)")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Manual", systemImage: "hand.raised")
                        }
                    } header: {
                        RetroSectionHeader("Statistics", icon: "chart.bar")
                    }
                }

                // About
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Labby", systemImage: "info.circle")
                    }

                    NavigationLink {
                        DebugLogView()
                    } label: {
                        Label("Debug Logs", systemImage: "doc.text.magnifyingglass")
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showingClearDataAlert = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                } header: {
                    RetroSectionHeader("Data", icon: "cylinder.split.1x2")
                } footer: {
                    Text("This will remove all connections and services. This action cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddConnection) {
                ConnectionSetupView()
            }
            .sheet(item: $connectionToEdit) { connection in
                ConnectionSetupView(connection: connection)
            }
            .sheet(isPresented: $showingAddService) {
                AddServiceView()
            }
            .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all \(connections.count) connections and \(services.count) services. This action cannot be undone.")
            }
        }
    }

    private func clearAllData() {
        try? modelContext.delete(model: HomepageConnection.self)
        try? modelContext.delete(model: Service.self)
        try? modelContext.delete(model: Bookmark.self)
    }
}

struct ConnectionRow: View {
    let connection: HomepageConnection

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Connection icon
            Image(systemName: "link.circle.fill")
                .font(.title2)
                .foregroundStyle(LabbyColors.primary(for: colorScheme))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(connection.name)
                    .font(.body.weight(.medium))

                Text(connection.baseURLString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let lastSync = connection.lastSync {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                        Text("Synced \(lastSync, style: .relative) ago")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Sync status indicator
            Circle()
                .fill(connection.lastSync != nil ? LabbyColors.primary(for: colorScheme) : Color.orange)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(connection.name), \(connection.baseURLString)")
        .accessibilityValue(connection.lastSync != nil ? "Synced" : "Not synced")
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Service.self, HomepageConnection.self, AppSettings.self], inMemory: true)
}

import SwiftUI
import SwiftData

struct ManualServicesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Service> { $0.isManuallyAdded },
        sort: \Service.sortOrder
    ) private var manualServices: [Service]

    @State private var showingAddService = false
    @State private var serviceToEdit: Service?
    @State private var serviceToDelete: Service?

    var body: some View {
        List {
            if manualServices.isEmpty {
                emptyState
            } else {
                servicesSection
            }
        }
        .navigationTitle("Manual Services")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddService = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddService) {
            AddServiceView()
        }
        .sheet(item: $serviceToEdit) { service in
            AddServiceView(service: service)
        }
        .alert("Delete Service?", isPresented: Binding(
            get: { serviceToDelete != nil },
            set: { if !$0 { serviceToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                serviceToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let service = serviceToDelete {
                    // Close any open tab first
                    if let tab = TabManager.shared.tabs.first(where: { $0.service.id == service.id }) {
                        TabManager.shared.closeTab(tab)
                    }
                    modelContext.delete(service)
                }
                serviceToDelete = nil
            }
        } message: {
            if let service = serviceToDelete {
                Text("Are you sure you want to delete \"\(service.name)\"? This action cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(LabbyColors.primary(for: colorScheme).opacity(0.5))

                VStack(spacing: 8) {
                    Text("No Manual Services")
                        .retroStyle(.headline, weight: .semibold)

                    Text("Add your own services to build a custom dashboard, or connect to Homepage to sync automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                LabbyButton(title: "Add Your First Service", icon: "plus.circle.fill") {
                    showingAddService = true
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    @ViewBuilder
    private var servicesSection: some View {
        Section {
            ForEach(manualServices) { service in
                ManualServiceRow(service: service)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        serviceToEdit = service
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            serviceToDelete = service
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            serviceToEdit = service
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(LabbyColors.primary(for: colorScheme))
                    }
            }
            .onMove(perform: moveServices)
        } header: {
            RetroSectionHeader("Services", icon: "square.grid.2x2")
        } footer: {
            Text("Tap to edit, swipe to delete, or drag to reorder.")
        }
    }

    private func moveServices(from source: IndexSet, to destination: Int) {
        var services = manualServices
        services.move(fromOffsets: source, toOffset: destination)

        // Update sort order for all affected services
        for (index, service) in services.enumerated() {
            service.sortOrder = index
        }

        try? modelContext.save()
    }
}

struct ManualServiceRow: View {
    let service: Service

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Service icon
            Group {
                if let sfSymbol = service.iconSFSymbol {
                    if sfSymbol.hasPrefix("emoji:") {
                        let emojiName = String(sfSymbol.dropFirst(6))
                        if let character = CategoryIconPicker.emoji(for: emojiName) {
                            Text(character)
                                .font(.title3)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: sfSymbol)
                            .font(.title3)
                            .foregroundStyle(LabbyColors.primary(for: colorScheme))
                    }
                } else if let iconURL = service.iconURL {
                    AsyncImage(url: iconURL) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "app.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 36)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LabbyColors.primary(for: colorScheme).opacity(0.1))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.body.weight(.medium))

                Text(service.urlString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let category = service.category {
                    Text(category)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Health status indicator
            Circle()
                .fill(healthColor)
                .frame(width: 8, height: 8)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(service.name), \(service.urlString)")
        .accessibilityValue(healthAccessibilityValue)
    }

    private var healthColor: Color {
        switch service.isHealthy {
        case .some(true): return LabbyColors.primary(for: colorScheme)
        case .some(false): return .red
        case .none: return .orange
        }
    }

    private var healthAccessibilityValue: String {
        switch service.isHealthy {
        case .some(true): return "Online"
        case .some(false): return "Offline"
        case .none: return "Status unknown"
        }
    }
}

#Preview {
    NavigationStack {
        ManualServicesView()
    }
    .modelContainer(for: [Service.self, AppSettings.self], inMemory: true)
}

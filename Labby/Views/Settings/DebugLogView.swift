import SwiftUI

struct DebugLogView: View {
    @State private var logger = DebugLogger.shared
    @State private var selectedCategory: String? = nil
    @State private var showShareSheet = false
    @State private var searchText = ""

    @Environment(\.colorScheme) private var colorScheme

    private var categories: [String] {
        Array(Set(logger.entries.map { $0.category })).sorted()
    }

    private var filteredEntries: [DebugLogEntry] {
        var entries = logger.entries

        if let category = selectedCategory {
            entries = entries.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            entries = entries.filter {
                $0.message.localizedCaseInsensitiveContains(searchText)
            }
        }

        return entries.reversed() // Most recent first
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            if categories.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )

                        ForEach(categories, id: \.self) { category in
                            FilterChip(
                                title: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))

                Divider()
            }

            // Log entries
            if filteredEntries.isEmpty {
                ContentUnavailableView {
                    Label("No Logs", systemImage: "doc.text")
                } description: {
                    Text("Debug logs will appear here as you use the app")
                }
            } else {
                List(filteredEntries) { entry in
                    LogEntryRow(entry: entry)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Debug Logs")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search logs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Export Logs", systemImage: "square.and.arrow.up")
                    }
                    .disabled(logger.entries.isEmpty)

                    Button(role: .destructive) {
                        logger.clear()
                    } label: {
                        Label("Clear Logs", systemImage: "trash")
                    }
                    .disabled(logger.entries.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [logger.exportLogs()])
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(isSelected
                              ? LabbyColors.primary(for: colorScheme)
                              : Color(.secondarySystemFill))
                }
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct LogEntryRow: View {
    let entry: DebugLogEntry

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: entry.timestamp)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.level.icon)
                .font(.caption)
                .foregroundStyle(entry.level.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(timeString)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                Text(entry.message)
                    .font(.caption)
                    .foregroundStyle(entry.level == .error ? entry.level.color : .primary)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        DebugLogView()
    }
    .onAppear {
        // Add sample logs for preview
        let logger = DebugLogger.shared
        logger.info("Loading URL: https://example.com", category: "WebView")
        logger.info("Navigation started", category: "WebView")
        logger.info("Response: 200 for https://example.com", category: "WebView")
        logger.info("Navigation finished", category: "WebView")
        logger.warning("HTTP error 404 for https://example.com/missing", category: "WebView")
        logger.error("SSL connection failed for https://badssl.com", category: "WebView")
    }
}

import SwiftUI

struct BrowserContainerView: View {
    @State private var tabManager = TabManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if tabManager.tabs.isEmpty {
                    EmptyBrowserView()
                } else {
                    BrowserTabsView(tabManager: tabManager)
                }
            }
            .navigationTitle("Browser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !tabManager.tabs.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                tabManager.closeAllTabs()
                            } label: {
                                Label("Close All Tabs", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }
}

struct EmptyBrowserView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Open Tabs")
                .font(.headline)

            Text("Tap a service on the Dashboard to open it here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct BrowserTabsView: View {
    @Bindable var tabManager: TabManager

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabManager.tabs) { tab in
                        TabButton(
                            tab: tab,
                            isActive: tab.id == tabManager.activeTabId,
                            onTap: {
                                tabManager.activeTabId = tab.id
                            },
                            onClose: {
                                tabManager.closeTab(tab)
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)

            Divider()

            // All tabs stacked - only active one is visible and interactable
            ZStack {
                ForEach(tabManager.tabs) { tab in
                    WebViewContainer(tab: tab)
                        .opacity(tab.id == tabManager.activeTabId ? 1 : 0)
                        .allowsHitTesting(tab.id == tabManager.activeTabId)
                }
            }
        }
    }
}

struct TabButton: View {
    @Bindable var tab: BrowserTab
    let isActive: Bool
    let onTap: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Loading indicator or icon
            if tab.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            } else if let sfSymbol = tab.service.iconSFSymbol {
                Image(systemName: sfSymbol)
                    .font(.caption)
            }

            Text(tab.title ?? tab.service.name)
                .font(.caption)
                .lineLimit(1)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
        }
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    BrowserContainerView()
}

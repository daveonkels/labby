import SwiftUI

struct BrowserContainerView: View {
    @State private var tabManager = TabManager.shared

    var body: some View {
        Group {
            if tabManager.tabs.isEmpty {
                NavigationStack {
                    EmptyBrowserView()
                        .navigationTitle("Browser")
                        .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                SwipeableBrowserView(tabManager: tabManager)
            }
        }
    }
}

// MARK: - Swipeable Browser View

struct SwipeableBrowserView: View {
    @Bindable var tabManager: TabManager
    @State private var selectedIndex: Int = 0
    @State private var toolbarVisible: Bool = true
    @State private var hideToolbarTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen swipeable tabs
            TabView(selection: $selectedIndex) {
                ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                    FullScreenWebView(tab: tab, onTap: showToolbar)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(.all) // Extend under status bar for seamless look
            .onChange(of: selectedIndex) { _, newIndex in
                syncActiveTab(to: newIndex)
            }
            .onAppear {
                syncSelectedIndex()
                scheduleToolbarHide()
            }

            // Floating toolbar overlay (auto-hides)
            VStack {
                Spacer()

                FloatingBrowserToolbar(
                    tab: currentTab,
                    tabCount: tabManager.tabs.count,
                    currentIndex: selectedIndex,
                    onClose: closeCurrentTab,
                    onCloseAll: { tabManager.closeAllTabs() }
                )
                .padding(.bottom, 60) // Space above page indicator
                .opacity(toolbarVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: toolbarVisible)

                // Page indicator - always visible, just above tab bar
                PageDots(
                    count: tabManager.tabs.count,
                    currentIndex: selectedIndex
                )
                .padding(.bottom, 4)
            }
        }
    }

    private var currentTab: BrowserTab? {
        guard selectedIndex < tabManager.tabs.count else { return nil }
        return tabManager.tabs[selectedIndex]
    }

    private func syncActiveTab(to index: Int) {
        guard index < tabManager.tabs.count else { return }
        tabManager.activeTabId = tabManager.tabs[index].id
    }

    private func syncSelectedIndex() {
        if let activeId = tabManager.activeTabId,
           let index = tabManager.tabs.firstIndex(where: { $0.id == activeId }) {
            selectedIndex = index
        }
    }

    private func showToolbar() {
        toolbarVisible = true
        scheduleToolbarHide()
    }

    private func scheduleToolbarHide() {
        hideToolbarTask?.cancel()
        hideToolbarTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled {
                await MainActor.run {
                    toolbarVisible = false
                }
            }
        }
    }

    private func closeCurrentTab() {
        guard let tab = currentTab else { return }
        let newIndex = max(0, selectedIndex - 1)
        tabManager.closeTab(tab)
        if !tabManager.tabs.isEmpty {
            selectedIndex = min(newIndex, tabManager.tabs.count - 1)
        }
    }
}

// MARK: - Full Screen Web View

struct FullScreenWebView: View {
    @Bindable var tab: BrowserTab
    let onTap: () -> Void

    var body: some View {
        WebViewRepresentable(tab: tab)
            .ignoresSafeArea(.all) // Extend under status bar and home indicator
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
    }
}

// MARK: - Floating Browser Toolbar

struct FloatingBrowserToolbar: View {
    let tab: BrowserTab?
    let tabCount: Int
    let currentIndex: Int
    let onClose: () -> Void
    let onCloseAll: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 20) {
            // Back button
            toolbarButton(
                icon: "chevron.left",
                action: { tab?.webView?.goBack() },
                disabled: !(tab?.canGoBack ?? false)
            )

            // Forward button
            toolbarButton(
                icon: "chevron.right",
                action: { tab?.webView?.goForward() },
                disabled: !(tab?.canGoForward ?? false)
            )

            // URL display
            urlDisplay

            // Reload button
            toolbarButton(
                icon: "arrow.clockwise",
                action: { tab?.webView?.reload() },
                disabled: false
            )

            // More options
            moreMenu
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(toolbarBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 16)
    }

    private func toolbarButton(icon: String, action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundColor(disabled ? .secondary.opacity(0.5) : .primary)
                .frame(width: 32, height: 32)
        }
        .disabled(disabled)
    }

    private var urlDisplay: some View {
        HStack(spacing: 6) {
            if tab?.isLoading == true {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Text(tab?.currentURL?.host ?? tab?.service.name ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var moreMenu: some View {
        Menu {
            if tabCount > 1 {
                Button(role: .destructive, action: onClose) {
                    Label("Close Tab", systemImage: "xmark")
                }
            }

            Button(role: .destructive, action: onCloseAll) {
                Label("Close All Tabs", systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.medium))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
        }
        .accessibilityLabel("Tab options")
    }

    private var toolbarBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
    }
}

// MARK: - Page Dots (Minimal indicator just above tab bar)

struct PageDots: View {
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.primary : Color.primary.opacity(0.3))
                    .frame(width: index == currentIndex ? 7 : 5, height: index == currentIndex ? 7 : 5)
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

struct EmptyBrowserView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            animatedGlobe
            descriptionText
        }
        .padding()
        .onAppear {
            isAnimating = true
        }
    }

    private var animatedGlobe: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 2)
                .frame(width: 100, height: 100)

            orbitingDot

            Image(systemName: "globe")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
        }
    }

    private var orbitingDot: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 8, height: 8)
            .offset(y: -50)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                .linear(duration: 3).repeatForever(autoreverses: false),
                value: isAnimating
            )
    }

    private var descriptionText: some View {
        VStack(spacing: 8) {
            Text("No Open Tabs")
                .font(.title3.weight(.semibold))

            Text("Tap a service on the Dashboard to open it here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

#Preview {
    BrowserContainerView()
}

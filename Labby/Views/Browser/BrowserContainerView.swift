import SwiftUI
import UIKit

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
    @State private var dotsVisible: Bool = true
    @State private var hideToolbarTask: Task<Void, Never>?
    @State private var hideDotsTask: Task<Void, Never>?

    // Close button state
    @State private var showCloseButton: Bool = false
    @State private var hideCloseButtonTask: Task<Void, Never>?

    // Scrubbing state
    @State private var isScrubbing: Bool = false
    @State private var scrubStartIndex: Int = 0

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
            .onChange(of: selectedIndex) { oldIndex, newIndex in
                syncActiveTab(to: newIndex)
                showDotsTemporarily()
                // Show close button when switching tabs
                if oldIndex != newIndex {
                    showCloseButtonWithTimer()
                }
            }
            .onAppear {
                syncSelectedIndex()
                scheduleToolbarHide()
                showDotsTemporarily()
            }

            // Close button - upper right (appears during tab navigation)
            if showCloseButton {
                VStack {
                    HStack {
                        Spacer()
                        FloatingCloseButton(onClose: closeCurrentTab)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .padding(.top, 54) // Fixed position just below Dynamic Island/notch
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
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

                // Page indicator with scrubbing gesture
                // Extra padding creates larger touch target for easier scrubbing
                PageDots(
                    count: tabManager.tabs.count,
                    currentIndex: selectedIndex
                )
                .padding(.horizontal, 40) // Extend touch area horizontally
                .padding(.vertical, 20)   // Extend touch area vertically
                .contentShape(Rectangle()) // Make entire padded area tappable
                .gesture(
                    LongPressGesture(minimumDuration: 0.15) // Slightly faster activation
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            switch value {
                            case .first(true):
                                // Long press recognized - start scrubbing
                                isScrubbing = true
                                scrubStartIndex = selectedIndex
                                showCloseButtonWithTimer()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                            case .second(true, let drag):
                                guard let drag = drag, isScrubbing else { return }
                                // Calculate new index based on drag offset
                                let dotSpacing: CGFloat = 18 // 10pt dot + 8pt spacing
                                let indexOffset = Int(drag.translation.width / dotSpacing)
                                let newIndex = max(0, min(tabManager.tabs.count - 1, scrubStartIndex + indexOffset))
                                if newIndex != selectedIndex {
                                    selectedIndex = newIndex
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }

                            default:
                                break
                            }
                        }
                        .onEnded { _ in
                            isScrubbing = false
                            showCloseButtonWithTimer()
                        }
                )
                .padding(.bottom, 12)
                .opacity(dotsVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: dotsVisible)
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
        showDotsTemporarily()
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

    private func showDotsTemporarily() {
        dotsVisible = true
        hideDotsTask?.cancel()
        hideDotsTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled {
                await MainActor.run {
                    dotsVisible = false
                }
            }
        }
    }

    private func closeCurrentTab() {
        guard currentTab != nil else { return }
        closeTab(at: selectedIndex)
    }

    private func closeTab(at index: Int) {
        guard index < tabManager.tabs.count else { return }
        let tab = tabManager.tabs[index]
        let newIndex = max(0, min(selectedIndex, tabManager.tabs.count - 2))
        tabManager.closeTab(tab)
        if !tabManager.tabs.isEmpty {
            selectedIndex = newIndex
        }
    }

    private func showCloseButtonWithTimer() {
        withAnimation(.easeInOut(duration: 0.2)) { showCloseButton = true }
        hideCloseButtonTask?.cancel()
        hideCloseButtonTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled && !isScrubbing {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) { showCloseButton = false }
                }
            }
        }
    }
}

// MARK: - Full Screen Web View

struct FullScreenWebView: View {
    @Bindable var tab: BrowserTab
    let onTap: () -> Void

    var body: some View {
        ZStack {
            WebViewRepresentable(tab: tab)
                .ignoresSafeArea(.all) // Extend under status bar and home indicator
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }

            // Show error overlay if load failed
            if let error = tab.loadError {
                WebViewErrorOverlay(
                    error: error,
                    url: tab.urlToLoad,
                    onRetry: {
                        tab.loadError = nil
                        if let url = tab.urlToLoad {
                            tab.webView?.load(URLRequest(url: url))
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Error Overlay

struct WebViewErrorOverlay: View {
    let error: String
    let url: URL?
    let onRetry: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Failed to Load")
                    .font(.title2.weight(.semibold))

                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let url = url {
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }

            Button(action: onRetry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.bordered)
            .tint(LabbyColors.primary(for: colorScheme))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
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

// MARK: - Page Dots (Weather app style indicator)

struct PageDots: View {
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.primary : Color.primary.opacity(0.3))
                    .frame(width: index == currentIndex ? 10 : 8, height: index == currentIndex ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: Capsule())
        .contentShape(Capsule())
    }
}

// MARK: - Floating Close Button

struct FloatingCloseButton: View {
    let onClose: () -> Void

    var body: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .glassEffect(.regular, in: Circle())
        }
    }
}

struct EmptyBrowserView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    private var primaryColor: Color {
        LabbyColors.primary(for: colorScheme)
    }

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
                .stroke(primaryColor.opacity(0.2), lineWidth: 2)
                .frame(width: 100, height: 100)

            orbitingDot

            Image(systemName: "globe")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
        }
    }

    private var orbitingDot: some View {
        Circle()
            .fill(primaryColor)
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
                .retroStyle(.title2, weight: .bold)

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

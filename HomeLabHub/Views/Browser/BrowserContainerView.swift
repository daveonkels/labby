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
                        .accessibilityLabel("Browser options")
                        .accessibilityHint("Opens menu with tab management options")
                    }
                }
            }
        }
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

    @Environment(\.colorScheme) private var colorScheme

    private var tabTitle: String {
        tab.title ?? tab.service.name
    }

    private var backgroundColor: Color {
        if isActive {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.12)
        }
        return Color.secondary.opacity(0.08)
    }

    var body: some View {
        HStack(spacing: 8) {
            leadingIcon
            titleLabel
            closeButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundShape)
        .overlay(borderOverlay)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tabTitle) tab")
        .accessibilityValue(isActive ? "Selected" : "")
        .accessibilityHint("Double tap to switch to this tab")
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if tab.isLoading {
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)
        } else if let sfSymbol = tab.service.iconSFSymbol {
            Image(systemName: sfSymbol)
                .font(.caption.weight(.medium))
                .foregroundColor(isActive ? .accentColor : .secondary)
        }
    }

    private var titleLabel: some View {
        Text(tabTitle)
            .font(.caption)
            .fontWeight(isActive ? .semibold : .regular)
            .lineLimit(1)
            .foregroundColor(isActive ? .primary : .secondary)
    }

    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
        }
        .accessibilityLabel("Close \(tabTitle) tab")
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(backgroundColor)
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if isActive {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1.5)
        }
    }
}

#Preview {
    BrowserContainerView()
}

import Foundation
import WebKit
import SwiftData

@Observable
final class BrowserTab: Identifiable {
    let id: UUID
    let service: Service
    weak var webView: WKWebView?
    var currentURL: URL?
    var title: String?
    var isLoading: Bool = false
    var canGoBack: Bool = false
    var canGoForward: Bool = false

    init(service: Service, restoredURL: URL? = nil) {
        self.id = UUID()
        self.service = service
        self.currentURL = restoredURL ?? service.url
        self.title = service.name
    }

    /// The URL to load - uses restored URL if available, otherwise service URL
    var urlToLoad: URL? {
        currentURL ?? service.url
    }
}

// MARK: - Tab Persistence

/// Represents a persisted tab state for storage
struct PersistedTabState: Codable {
    let serviceId: UUID
    let currentURLString: String?

    init(from tab: BrowserTab) {
        self.serviceId = tab.service.id
        self.currentURLString = tab.currentURL?.absoluteString
    }
}

/// Represents all persisted browser state
struct PersistedBrowserState: Codable {
    let tabs: [PersistedTabState]
    let activeServiceId: UUID?

    static let userDefaultsKey = "Labby.BrowserState"
}

@Observable
final class TabManager {
    static let shared = TabManager()

    var tabs: [BrowserTab] = []
    var activeTabId: UUID?
    private var hasRestoredTabs = false

    var activeTab: BrowserTab? {
        guard let activeTabId else { return nil }
        return tabs.first { $0.id == activeTabId }
    }

    private init() {}

    func openService(_ service: Service) -> BrowserTab {
        // Check if we already have a tab for this service
        if let existingTab = tabs.first(where: { $0.service.id == service.id }) {
            activeTabId = existingTab.id
            saveTabs()
            return existingTab
        }

        // Create new tab
        let tab = BrowserTab(service: service)
        tabs.append(tab)
        activeTabId = tab.id
        saveTabs()
        return tab
    }

    func closeTab(_ tab: BrowserTab) {
        // Clean up WebView to prevent memory leaks
        tab.webView?.stopLoading()
        tab.webView = nil

        tabs.removeAll { $0.id == tab.id }

        if activeTabId == tab.id {
            activeTabId = tabs.last?.id
        }
        saveTabs()
    }

    func closeAllTabs() {
        // Clean up all WebViews to prevent memory leaks
        for tab in tabs {
            tab.webView?.stopLoading()
            tab.webView = nil
        }
        tabs.removeAll()
        activeTabId = nil
        saveTabs()
    }

    // MARK: - Persistence

    /// Saves current tab state to UserDefaults
    private func saveTabs() {
        let persistedTabs = tabs.map { PersistedTabState(from: $0) }
        let activeServiceId = activeTab?.service.id

        let state = PersistedBrowserState(
            tabs: persistedTabs,
            activeServiceId: activeServiceId
        )

        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: PersistedBrowserState.userDefaultsKey)
        }
    }

    /// Restores tabs from UserDefaults, looking up Services from the model context
    @MainActor
    func restoreTabs(modelContext: ModelContext) {
        // Only restore once per app launch
        guard !hasRestoredTabs else { return }
        hasRestoredTabs = true

        guard let data = UserDefaults.standard.data(forKey: PersistedBrowserState.userDefaultsKey),
              let state = try? JSONDecoder().decode(PersistedBrowserState.self, from: data),
              !state.tabs.isEmpty else {
            return
        }

        // Fetch all services to match against saved tabs
        let descriptor = FetchDescriptor<Service>()
        guard let services = try? modelContext.fetch(descriptor) else {
            return
        }

        let serviceById = Dictionary(uniqueKeysWithValues: services.map { ($0.id, $0) })

        // Restore tabs
        var restoredCount = 0
        for persistedTab in state.tabs {
            guard let service = serviceById[persistedTab.serviceId] else {
                // Service was deleted, skip this tab
                continue
            }

            let restoredURL = persistedTab.currentURLString.flatMap { URL(string: $0) }
            let tab = BrowserTab(service: service, restoredURL: restoredURL)
            tabs.append(tab)
            restoredCount += 1

            // Set as active if it was the active tab
            if state.activeServiceId == service.id {
                activeTabId = tab.id
            }
        }

        // If no active tab was set, use the first one
        if activeTabId == nil && !tabs.isEmpty {
            activeTabId = tabs.first?.id
        }
    }

    /// Updates the current URL for a tab (called when navigation completes)
    func updateTabURL(_ tab: BrowserTab, url: URL?) {
        tab.currentURL = url
        saveTabs()
    }
}

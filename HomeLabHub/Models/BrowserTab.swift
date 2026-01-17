import Foundation
import WebKit

@Observable
final class BrowserTab: Identifiable {
    let id: UUID
    let service: Service
    var webView: WKWebView?
    var currentURL: URL?
    var title: String?
    var isLoading: Bool = false
    var canGoBack: Bool = false
    var canGoForward: Bool = false

    init(service: Service) {
        self.id = UUID()
        self.service = service
        self.currentURL = service.url
        self.title = service.name
    }
}

@Observable
final class TabManager {
    static let shared = TabManager()

    var tabs: [BrowserTab] = []
    var activeTabId: UUID?

    var activeTab: BrowserTab? {
        guard let activeTabId else { return nil }
        return tabs.first { $0.id == activeTabId }
    }

    private init() {}

    func openService(_ service: Service) -> BrowserTab {
        // Check if we already have a tab for this service
        if let existingTab = tabs.first(where: { $0.service.id == service.id }) {
            activeTabId = existingTab.id
            return existingTab
        }

        // Create new tab
        let tab = BrowserTab(service: service)
        tabs.append(tab)
        activeTabId = tab.id
        return tab
    }

    func closeTab(_ tab: BrowserTab) {
        tabs.removeAll { $0.id == tab.id }

        if activeTabId == tab.id {
            activeTabId = tabs.last?.id
        }
    }

    func closeAllTabs() {
        tabs.removeAll()
        activeTabId = nil
    }
}

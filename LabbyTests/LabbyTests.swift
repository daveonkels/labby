import XCTest
@testable import Labby

final class LabbyTests: XCTestCase {

    func testServiceInitialization() throws {
        let service = Service(
            name: "Test Service",
            urlString: "http://localhost:8080",
            iconSFSymbol: "server.rack",
            category: "Test"
        )

        XCTAssertEqual(service.name, "Test Service")
        XCTAssertEqual(service.urlString, "http://localhost:8080")
        XCTAssertNotNil(service.url)
        XCTAssertEqual(service.category, "Test")
        XCTAssertFalse(service.isManuallyAdded)
    }

    func testServiceURLParsing() throws {
        let service = Service(
            name: "Test",
            urlString: "http://192.168.1.100:3000/path"
        )

        let url = service.url
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "192.168.1.100")
        XCTAssertEqual(url?.port, 3000)
        XCTAssertEqual(url?.path, "/path")
    }

    func testHomepageConnectionInitialization() throws {
        let connection = HomepageConnection(
            baseURLString: "http://localhost:3000",
            name: "Test Homepage"
        )

        XCTAssertEqual(connection.name, "Test Homepage")
        XCTAssertEqual(connection.baseURLString, "http://localhost:3000")
        XCTAssertNotNil(connection.baseURL)
        XCTAssertTrue(connection.syncEnabled)
        XCTAssertNil(connection.lastSync)
    }

    func testBrowserTabCreation() throws {
        let service = Service(
            name: "Test Service",
            urlString: "http://localhost:8080"
        )

        let tab = BrowserTab(service: service)

        XCTAssertEqual(tab.service.id, service.id)
        XCTAssertEqual(tab.title, "Test Service")
        XCTAssertEqual(tab.currentURL, service.url)
        XCTAssertFalse(tab.isLoading)
        XCTAssertFalse(tab.canGoBack)
        XCTAssertFalse(tab.canGoForward)
    }

    func testTabManagerOpenService() throws {
        let tabManager = TabManager.shared
        tabManager.closeAllTabs()

        let service = Service(
            name: "Test Service",
            urlString: "http://localhost:8080"
        )

        let tab1 = tabManager.openService(service)
        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.activeTabId, tab1.id)

        // Opening same service should return existing tab
        let tab2 = tabManager.openService(service)
        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tab1.id, tab2.id)

        tabManager.closeAllTabs()
    }
}

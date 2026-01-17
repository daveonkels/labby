# Changelog

All notable changes to HomeLabHub are documented here.

## [0.1.0] - 2025-01-17

### Added

#### Core Infrastructure
- Xcode project setup with XcodeGen (`project.yml`)
- SwiftUI app lifecycle with SwiftData integration
- iOS 17.0 minimum deployment target
- SwiftSoup dependency for HTML parsing

#### Data Models
- `Service` model: name, URL, icon, category, health status, manual flag
- `HomepageConnection` model: base URL, name, sync settings
- `BrowserTab` observable class with WKWebView reference
- `TabManager` singleton for managing open tabs

#### Homepage Integration
- `HomepageClient` fetches and parses Homepage HTML
- Extracts services from Next.js `__NEXT_DATA__` JSON payload
- Parses `props.pageProps.fallback["/api/services"]` structure
- Resolves icon URLs (CDN, relative paths, SI/MDI icons)
- `SyncManager` coordinates sync with SwiftData persistence

#### Dashboard
- Grid layout with category grouping
- `ServiceCard` with icon, name, health indicator
- Services without URLs show "Widget Only" and are disabled
- Pull-to-refresh triggers sync
- Search/filter functionality

#### Browser
- WKWebView-based embedded browser
- Persistent cookies via `WKWebsiteDataStore.default()`
- Tab bar with loading indicators
- All tabs kept in memory (ZStack with opacity toggle)
- Back/forward navigation
- Reload button
- URL display in toolbar

#### Settings
- Add Homepage connection with URL validation
- Test connection before saving
- Add manual services with icon picker
- Clear all data option

#### Navigation
- Environment-based tab switching
- Tapping service card opens browser and switches to Browser tab
- Tab persistence when navigating away

### Technical Notes
- App Transport Security configured for local network access
- Debug logging in HomepageClient and SyncManager (remove for production)

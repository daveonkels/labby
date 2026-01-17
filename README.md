# HomeLabHub

A native iOS app for homelab enthusiasts that connects to self-hosted [Homepage](https://gethomepage.dev) dashboards, presenting services in a polished native UI with an embedded browser for accessing web-based services without leaving the app.

## Features

- **Homepage Integration**: Syncs services from your Homepage instance by parsing the Next.js `__NEXT_DATA__` payload
- **Native Dashboard**: Services displayed in a grid with category grouping
- **Embedded Browser**: WKWebView-based tabs with persistent cookies/sessions
- **Tab Persistence**: All open tabs stay in memory—switch between them without reloading
- **Manual Services**: Add services that aren't in your Homepage config

## Requirements

- iOS 17.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation

## Setup

1. **Clone the repository**
   ```bash
   cd ~/Dev/homelabhub
   ```

2. **Generate Xcode project**
   ```bash
   xcodegen generate
   ```

3. **Open in Xcode**
   ```bash
   open HomeLabHub.xcodeproj
   ```

4. **Build and Run** (⌘R)

## Architecture

### Tech Stack
- **UI**: SwiftUI (iOS 17+)
- **Data**: SwiftData for persistence
- **Networking**: URLSession + async/await
- **HTML Parsing**: [SwiftSoup](https://github.com/scinfu/SwiftSoup)
- **Browser**: WKWebView with persistent WKWebsiteDataStore

### Project Structure

```
HomeLabHub/
├── App/
│   ├── HomeLabHubApp.swift      # Entry point, SwiftData container
│   └── ContentView.swift        # Root view, tab navigation, environment setup
├── Models/
│   ├── Service.swift            # SwiftData model for services
│   ├── HomepageConnection.swift # SwiftData model for Homepage connections
│   └── BrowserTab.swift         # Observable tab state + TabManager singleton
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift  # Main grid with categories
│   │   └── ServiceCard.swift    # Individual service cards
│   ├── Browser/
│   │   ├── BrowserContainerView.swift  # Tab bar + ZStack of WebViews
│   │   └── WebViewRepresentable.swift  # WKWebView wrapper
│   └── Settings/
│       ├── SettingsView.swift          # Main settings
│       └── ConnectionSetupView.swift   # Add connection + manual service
├── Services/
│   ├── HomepageClient.swift     # Fetches & parses Homepage HTML
│   ├── SyncManager.swift        # Orchestrates sync, updates SwiftData
│   └── HealthChecker.swift      # Service health polling (not yet wired up)
└── Utilities/
    └── HapticManager.swift      # Haptic feedback helpers
```

### Key Components

**TabManager** (`BrowserTab.swift`)
- Singleton managing all open browser tabs
- Each `BrowserTab` holds a reference to its `WKWebView`
- Tabs persist in memory for instant switching

**HomepageClient** (`HomepageClient.swift`)
- Fetches Homepage HTML and extracts `__NEXT_DATA__` JSON
- Parses services from `props.pageProps.fallback["/api/services"]`
- Resolves icon URLs (dashboard-icons CDN, relative paths, etc.)

**SyncManager** (`SyncManager.swift`)
- Coordinates sync between Homepage and SwiftData
- Handles create/update/delete of services
- Preserves manually-added services during sync

## Network Configuration

The app allows arbitrary network loads for local homelab access:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

## Usage

1. **First Launch**: Tap "Connect to Homepage" and enter your Homepage URL
2. **Sync**: Services are automatically synced; pull-to-refresh on Dashboard to re-sync
3. **Open Service**: Tap any service card to open it in the embedded browser
4. **Switch Tabs**: Use the tab bar at the top of the Browser view
5. **Manual Services**: Settings → "Add Service Manually"

## License

Private project - not yet licensed for distribution.

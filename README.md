# HomeLabHub

A native iOS app for homelab enthusiasts that connects to self-hosted [Homepage](https://gethomepage.dev) dashboards, presenting services in a polished native UI with an embedded browser for accessing web-based services without leaving the app.

## Features

### Dashboard
- **Homepage Integration**: Syncs services from your Homepage instance by parsing the Next.js `__NEXT_DATA__` payload
- **Native Dashboard**: Services displayed in a grid with category grouping and health status indicators
- **iOS 26 Liquid Glass UI**: Native TabView with floating search button using iOS 26 design language
- **Health Monitoring**: Background polling shows online/offline status for each service with visual indicators
- **Status Filtering**: Filter dashboard by online/offline status; filter floats to header when active
- **Quick Search**: Tap the search button to find services by name across all categories
- **Themed Icons**: Automatic dark/light mode icon variants for Dashboard Icons and Simple Icons CDNs
- **Custom Backgrounds**: Personalize dashboard with images from photo library or AI-generated art via Apple Intelligence

### Browser
- **Embedded Browser**: WKWebView-based tabs with persistent cookies/sessions
- **Swipeable Tabs**: Swipe between open tabs with page indicator dots
- **Tab Persistence**: Open tabs persist across app restarts via UserDefaults
- **Safe Area Handling**: CSS injection ensures web content doesn't hide under the status bar/notch
- **Auto-hiding Toolbar**: Floating toolbar with back/forward/reload appears on tap, auto-hides after 4 seconds

### Tab Management
- **Blue Dot Indicators**: Dashboard cards show a blue dot when a service has an open browser tab
- **Long-press to Open**: Long-press a service card to open it in the background without leaving the dashboard
- **Long-press to Close**: Long-press a service card with an open tab to close it from the dashboard
- **Quick Close**: Long-press the page dots in the browser to close the current tab

### General
- **Self-Signed SSL Support**: Accepts self-signed certificates common in homelab environments
- **Manual Services**: Add services that aren't in your Homepage config
- **Appearance Settings**: Light, dark, or system appearance preference

## Requirements

- iOS 26.0+
- Xcode 26.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation
- Device with Apple Intelligence support (for AI background generation)

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
- **UI**: SwiftUI with iOS 26 Liquid Glass effects
- **Data**: SwiftData for persistence
- **Networking**: URLSession + async/await
- **HTML Parsing**: [SwiftSoup](https://github.com/scinfu/SwiftSoup)
- **Browser**: WKWebView with persistent WKWebsiteDataStore
- **AI**: Apple Intelligence ImagePlayground for background generation

### Project Structure

```
HomeLabHub/
├── App/
│   ├── HomeLabHubApp.swift      # Entry point, SwiftData container
│   └── ContentView.swift        # Root view, tab navigation, environment setup
├── Models/
│   ├── Service.swift            # SwiftData model for services
│   ├── HomepageConnection.swift # SwiftData model for Homepage connections
│   ├── BrowserTab.swift         # Observable tab state + TabManager singleton
│   ├── AppSettings.swift        # User preferences (appearance, background)
│   └── Bookmark.swift           # Bookmark model for services
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift     # Main grid with categories
│   │   ├── ServiceCard.swift       # Individual service cards with gestures
│   │   └── SearchResultsView.swift # Quick search results
│   ├── Browser/
│   │   ├── BrowserContainerView.swift  # Swipeable tabs + floating toolbar
│   │   └── WebViewRepresentable.swift  # WKWebView wrapper + safe area CSS
│   └── Settings/
│       ├── SettingsView.swift          # Main settings
│       ├── ConnectionSetupView.swift   # Add connection + manual service
│       └── BackgroundSettingsView.swift # Custom background picker
├── Services/
│   ├── HomepageClient.swift     # Fetches & parses Homepage HTML
│   ├── SyncManager.swift        # Orchestrates sync, updates SwiftData
│   ├── HealthChecker.swift      # Background service health monitoring
│   └── InsecureURLSession.swift # SSL bypass for self-signed certificates
└── Utilities/
    └── HapticManager.swift      # Haptic feedback helpers
```

### Key Components

**TabManager** (`BrowserTab.swift`)
- Singleton managing all open browser tabs
- Each `BrowserTab` holds a reference to its `WKWebView`
- Persists tab state to UserDefaults (service ID + current URL)
- Restores tabs on app launch by matching service IDs

**HomepageClient** (`HomepageClient.swift`)
- Fetches Homepage HTML and extracts `__NEXT_DATA__` JSON
- Parses services from `props.pageProps.fallback["/api/services"]`
- Resolves icon URLs (dashboard-icons CDN, relative paths, etc.)

**SyncManager** (`SyncManager.swift`)
- Coordinates sync between Homepage and SwiftData
- Handles create/update/delete of services
- Preserves manually-added services during sync

**HealthChecker** (`HealthChecker.swift`)
- Actor-based singleton for thread-safe health monitoring
- Polls services every 60 seconds with limited concurrency
- Falls back to GET request if HEAD returns 5xx (for servers that don't support HEAD)
- Updates service health status (online/offline) in SwiftData

**IconURLTransformer** (`ServiceCard.swift`)
- Transforms icon URLs for dark/light mode variants
- Dashboard Icons: appends `-light.png` suffix in dark mode
- Simple Icons: appends `/white` path in dark mode
- Falls back to original URL if themed variant doesn't exist

**SafeAreaInjector** (`WebViewRepresentable.swift`)
- Injects CSS via WKUserScript to handle safe areas
- Adds `padding-top: env(safe-area-inset-top)` to pages without sufficient padding
- Ensures `viewport-fit=cover` is set for proper safe area detection

**InsecureURLSession** (`InsecureURLSession.swift`)
- Shared URLSession that bypasses SSL certificate validation
- Essential for homelab environments with self-signed certs
- Used by HealthChecker, HomepageClient, and ConnectionSetupView

## Network Configuration

The app is configured for homelab environments:

**App Transport Security** (Info.plist):
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

**Self-Signed Certificates**: All network requests use `InsecureURLSession` which implements a custom `URLSessionDelegate` to accept any server certificate. This allows connecting to services using self-signed SSL certificates without certificate errors.

## Usage

### Getting Started
1. **First Launch**: Tap "Connect to Homepage" and enter your Homepage URL
2. **Sync**: Services are automatically synced; pull-to-refresh on Dashboard to re-sync
3. **Health Status**: Services show online (green) or offline (red) indicators updated every 60 seconds

### Dashboard
- **Open Service**: Tap any service card to open it in the embedded browser
- **Open in Background**: Long-press a service card to open it without leaving the dashboard
- **Close Tab from Dashboard**: Long-press a service with a blue dot indicator to close its tab
- **Filter Services**: Tap the status filter in the header to show only online or offline services
- **Search**: Tap the search button to find services by name

### Browser
- **Switch Tabs**: Swipe left/right to switch between open tabs
- **Show Toolbar**: Tap anywhere to show the floating toolbar (auto-hides after 4 seconds)
- **Close Tab**: Long-press the page dots to close the current tab, or use the toolbar menu
- **Navigation**: Use back/forward buttons in the toolbar, or swipe from edges

### Settings
- **Manual Services**: Add services that aren't in your Homepage config
- **Appearance**: Choose light, dark, or system appearance
- **Background**: Set a custom dashboard background from your photo library or generate one with AI

## License

Private project - not yet licensed for distribution.

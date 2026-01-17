# TODO

## High Priority

### Bug Fixes
- [ ] Remove debug `print()` statements from HomepageClient and SyncManager

### Core Features
- [ ] **Health Checking**: Wire up `HealthChecker` to actually poll services
  - Run on app launch and periodically (every 60s)
  - Update `service.isHealthy` and `service.lastHealthCheck`
  - Show green/red dots on service cards
- [ ] **Browser Error States**: Show error UI when page fails to load
  - Retry button
  - Error message display
  - Handle common errors (no network, timeout, SSL errors)
- [ ] **Edit/Delete Services**: Allow editing synced and manual services
- [ ] **Bookmarks Sync**: Homepage has `/api/bookmarks` - consider syncing these too

## Medium Priority

### Network & Connectivity
- [ ] **Network Reachability**: Detect when Tailscale/VPN is disconnected
  - Show banner or alert when services are unreachable
  - Deep-link to Tailscale app
- [ ] **Offline Mode**: Cache service list for offline viewing
- [ ] **Connection Profiles**: Support multiple Homepage instances

### UI Polish
- [ ] **Custom Service Cards**: More distinctive design, not stock iOS
- [ ] **Animations**: Card-to-browser transition, loading skeletons
- [ ] **Typography & Color**: Establish visual identity
- [ ] **App Icon**: Design and add proper app icon
- [ ] **Dark Mode**: Verify all views work well in dark mode
- [ ] **iPad Layout**: Multi-column layout for larger screens

### Browser Improvements
- [ ] **Tab Limit**: Warn or auto-close old tabs when too many open
- [ ] **Find in Page**: Text search within web content
- [ ] **Share**: Share current URL
- [ ] **Open in Safari**: Option to open in external browser

## Low Priority

### Platform Features
- [ ] **iOS Widgets**: Show service status on home screen
- [ ] **Spotlight Search**: Index services for system search
- [ ] **Siri Shortcuts**: "Open Plex" voice commands
- [ ] **Apple Watch**: Companion app for quick status checks

### Future Integrations
- [ ] **Homarr Support**: Parse Homarr dashboard format
- [ ] **Dashy Support**: Parse Dashy configuration
- [ ] **iCloud Sync**: Sync manual services across devices

### Code Quality
- [ ] **Unit Tests**: HomepageClient parsing, SyncManager logic
- [ ] **UI Tests**: Dashboard navigation, browser tab management
- [ ] **Error Handling**: Comprehensive error types and user messaging
- [ ] **Logging**: Structured logging with log levels (remove debug prints)

## Before App Store Submission

- [ ] Remove all debug logging
- [ ] Add privacy policy URL
- [ ] Configure App Store Connect metadata
- [ ] Create App Store screenshots (all device sizes)
- [ ] Write App Store description
- [ ] Set up TestFlight for beta testing
- [ ] Review App Transport Security settings for production

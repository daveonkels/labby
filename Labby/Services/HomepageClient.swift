import Foundation
import SwiftSoup

struct HomepageClient {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Fetches and parses all data from Homepage HTML
    func fetchAll() async throws -> (services: [ParsedService], bookmarks: [ParsedBookmark]) {
        let (data, _) = try await InsecureURLSession.shared.data(from: baseURL)

        guard let html = String(data: data, encoding: .utf8) else {
            throw HomepageError.invalidHTML
        }

        return try parseHTML(html)
    }

    /// Fetches and parses services from Homepage HTML (legacy, for backward compatibility)
    func fetchServices() async throws -> [ParsedService] {
        return try await fetchAll().services
    }

    /// Parses Homepage HTML to extract services and bookmarks
    private func parseHTML(_ html: String) throws -> (services: [ParsedService], bookmarks: [ParsedBookmark]) {
        let document = try SwiftSoup.parse(html)
        var services: [ParsedService] = []
        let bookmarks: [ParsedBookmark] = []

        // Homepage is a Next.js app - data is in __NEXT_DATA__ script tag
        if let nextDataScript = try? document.select("script#__NEXT_DATA__").first() {
            let jsonString = try nextDataScript.html()

            if let data = jsonString.data(using: .utf8) {
                let (parsedServices, parsedBookmarks) = try parseNextData(data)
                if !parsedServices.isEmpty || !parsedBookmarks.isEmpty {
                    return (parsedServices, parsedBookmarks)
                }
            }
        }

        // Fallback: Try DOM-based parsing
        // Find all service groups (sections with service-group-name class)
        let groups = try document.select("h2.service-group-name, div.service-group-name")

        for group in groups {
            let groupName = try group.text().trimmingCharacters(in: .whitespacesAndNewlines)

            // Find the services list that follows this group header
            // Services are in <li> elements with class "service"
            guard let parent = group.parent() else { continue }

            let serviceElements = try parent.select("li.service, div.service")

            for serviceElement in serviceElements {
                // Get service name from data-name attribute or text content
                let serviceName = try serviceElement.attr("data-name").isEmpty
                    ? extractServiceName(from: serviceElement)
                    : serviceElement.attr("data-name")

                guard !serviceName.isEmpty else { continue }

                // Get href from the main link
                let href = try extractHref(from: serviceElement)

                // Get icon URL if present
                let iconURL = try extractIconURL(from: serviceElement)

                // Get description if present
                let description = try extractDescription(from: serviceElement)

                let service = ParsedService(
                    id: try serviceElement.attr("id").isEmpty ? serviceName : serviceElement.attr("id"),
                    name: serviceName,
                    href: href,
                    iconURL: iconURL,
                    description: description,
                    category: groupName,
                    sortOrder: services.count
                )

                services.append(service)
            }
        }

        // If no groups found, try finding services directly
        if services.isEmpty {
            let serviceElements = try document.select("li.service, div.service, [class*='service-']")

            for serviceElement in serviceElements {
                let serviceName = try serviceElement.attr("data-name").isEmpty
                    ? extractServiceName(from: serviceElement)
                    : serviceElement.attr("data-name")

                guard !serviceName.isEmpty else { continue }

                let href = try extractHref(from: serviceElement)
                let iconURL = try extractIconURL(from: serviceElement)
                let description = try extractDescription(from: serviceElement)

                let service = ParsedService(
                    id: serviceName,
                    name: serviceName,
                    href: href,
                    iconURL: iconURL,
                    description: description,
                    category: nil,
                    sortOrder: services.count
                )

                services.append(service)
            }
        }

        return (services, bookmarks)
    }

    private func extractServiceName(from element: Element) throws -> String {
        // Try various selectors for the service name
        if let titleElement = try? element.select(".service-title a, .service-title span, .service-name").first() {
            return try titleElement.text().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try finding any link text
        if let link = try? element.select("a").first() {
            let text = try link.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text
            }
        }

        return ""
    }

    private func extractHref(from element: Element) throws -> String? {
        // Look for href in various link elements
        if let link = try? element.select("a[href]").first() {
            let href = try link.attr("href")
            if !href.isEmpty && href != "#" {
                return resolveURL(href)
            }
        }
        return nil
    }

    private func extractIconURL(from element: Element) throws -> String? {
        // Look for icon image
        if let img = try? element.select("img[src]").first() {
            let src = try img.attr("src")
            if !src.isEmpty {
                return resolveURL(src)
            }
        }

        // Look for background image in style
        if let iconDiv = try? element.select("[style*='background-image']").first() {
            let style = try iconDiv.attr("style")
            if let urlMatch = style.range(of: "url\\(['\"]?([^'\"\\)]+)['\"]?\\)", options: .regularExpression) {
                let urlString = String(style[urlMatch])
                    .replacingOccurrences(of: "url(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .replacingOccurrences(of: "'", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                return resolveURL(urlString)
            }
        }

        return nil
    }

    private func extractDescription(from element: Element) throws -> String? {
        if let descElement = try? element.select(".service-description, .description, p").first() {
            let text = try descElement.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text
            }
        }
        return nil
    }

    /// Parse Next.js __NEXT_DATA__ JSON to extract services and bookmarks
    private func parseNextData(_ data: Data) throws -> (services: [ParsedService], bookmarks: [ParsedBookmark]) {
        var services: [ParsedService] = []
        var bookmarks: [ParsedBookmark] = []

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let props = json["props"] as? [String: Any],
              let pageProps = props["pageProps"] as? [String: Any] else {
            return ([], [])
        }

        // Homepage stores services in fallback["/api/services"]
        // Structure: [ { name: "GroupName", services: [ { name, href, icon, ... } ] } ]

        var serviceGroups: [[String: Any]]? = nil
        var bookmarkGroups: [[String: Any]]? = nil

        // Try fallback first (SWR pattern)
        if let fallback = pageProps["fallback"] as? [String: Any] {
            if let apiServices = fallback["/api/services"] as? [[String: Any]] {
                serviceGroups = apiServices
            }
            if let apiBookmarks = fallback["/api/bookmarks"] as? [[String: Any]] {
                bookmarkGroups = apiBookmarks
            }
        }

        // Fallback to direct keys
        if serviceGroups == nil {
            if let s = pageProps["services"] as? [[String: Any]] {
                serviceGroups = s
            }
        }
        if bookmarkGroups == nil {
            if let b = pageProps["bookmarks"] as? [[String: Any]] {
                bookmarkGroups = b
            }
        }

        // Parse bookmarks
        if let groups = bookmarkGroups {
            var bookmarkSortOrder = 0

            for groupDict in groups {
                let groupName = groupDict["name"] as? String ?? "Bookmarks"
                guard let bookmarksList = groupDict["bookmarks"] as? [[String: Any]] else { continue }

                for bookmarkInfo in bookmarksList {
                    let name = bookmarkInfo["name"] as? String ?? "Unknown"
                    guard let href = bookmarkInfo["href"] as? String else { continue }
                    let abbr = bookmarkInfo["abbr"] as? String

                    let bookmark = ParsedBookmark(
                        id: "\(groupName)-\(name)",
                        name: name,
                        abbreviation: abbr,
                        href: href,
                        category: groupName,
                        sortOrder: bookmarkSortOrder
                    )
                    bookmarks.append(bookmark)
                    bookmarkSortOrder += 1
                }
            }
        }

        guard let groups = serviceGroups else {
            return ([], bookmarks)
        }

        // Parse each service group
        for groupDict in groups {
            let groupName = groupDict["name"] as? String ?? "Other"
            guard let servicesList = groupDict["services"] as? [[String: Any]] else { continue }

            for serviceInfo in servicesList {
                let serviceName = serviceInfo["name"] as? String ?? "Unknown"
                let href = serviceInfo["href"] as? String

                // Skip widgets (they don't have an href, only services do)
                guard href != nil else {
                    continue
                }

                let icon = serviceInfo["icon"] as? String
                let description = serviceInfo["description"] as? String

                // Resolve icon URL
                var iconURL: String? = nil
                if let icon = icon {
                    if icon.hasPrefix("http") {
                        iconURL = icon
                    } else if icon.hasPrefix("/") {
                        iconURL = resolveURL(icon)
                    } else if icon.hasPrefix("si-") {
                        // Simple Icons - use simpleicons.org CDN
                        let iconName = String(icon.dropFirst(3)) // Remove "si-" prefix
                        iconURL = "https://cdn.simpleicons.org/\(iconName)"
                    } else if icon.hasPrefix("sh-") {
                        // Self-hosted icons from selfhst/icons repository
                        let iconName = normalizeIconName(String(icon.dropFirst(3))) // Remove "sh-" prefix
                        iconURL = "https://cdn.jsdelivr.net/gh/selfhst/icons@main/png/\(iconName).png"
                    } else if icon.hasPrefix("mdi-") {
                        // Material Design Icons from @mdi/svg via jsdelivr CDN
                        // Format: mdi-{icon-name} or mdi-{icon-name}-#{color}
                        let iconPart = String(icon.dropFirst(4)) // Remove "mdi-" prefix
                        let (iconName, colorHex) = extractMDIIconNameAndColor(iconPart)
                        var mdiURL = "https://cdn.jsdelivr.net/npm/@mdi/svg@latest/svg/\(iconName).svg"
                        // Encode color in URL fragment for SVGIconView to use
                        if let color = colorHex {
                            mdiURL += "#\(color)"
                        }
                        iconURL = mdiURL
                    } else {
                        // Dashboard icon - use CDN URL with normalized name
                        let normalizedIcon = normalizeIconName(icon)
                        iconURL = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/\(normalizedIcon).png"
                    }
                }

                let service = ParsedService(
                    id: serviceName,
                    name: serviceName,
                    href: href,
                    iconURL: iconURL,
                    description: description,
                    category: groupName,
                    sortOrder: services.count
                )

                services.append(service)
            }
        }

        return (services, bookmarks)
    }

    /// Normalizes icon name to match dashboard-icons repository naming convention
    /// - Parameter name: The icon name from Homepage config
    /// - Returns: Normalized icon name (lowercase, kebab-case, no extension)
    private func normalizeIconName(_ name: String) -> String {
        return name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ".png", with: "")
            .replacingOccurrences(of: ".svg", with: "")
            .replacingOccurrences(of: ".webp", with: "")
    }

    /// Extracts MDI icon name and optional color from the icon identifier
    /// - Parameter iconPart: The icon identifier after "mdi-" prefix (e.g., "chat-processing" or "chat-processing-#9333ea")
    /// - Returns: Tuple of (icon name, optional hex color without #)
    private func extractMDIIconNameAndColor(_ iconPart: String) -> (name: String, color: String?) {
        // MDI icons can have an optional color suffix like "-#f0d453"
        // We need to find the last occurrence of "-#" and extract the color
        if let colorRange = iconPart.range(of: "-#[0-9a-fA-F]+$", options: .regularExpression) {
            let name = String(iconPart[..<colorRange.lowerBound])
            // Extract color hex (skip the "-#" prefix)
            let colorStart = iconPart.index(colorRange.lowerBound, offsetBy: 2)
            let color = String(iconPart[colorStart...])
            return (name, color)
        }
        return (iconPart, nil)
    }

    private func resolveURL(_ urlString: String) -> String {
        // If it's already absolute, return as-is
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }

        // Resolve relative URLs against base URL
        if urlString.hasPrefix("/") {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = urlString
            return components?.url?.absoluteString ?? urlString
        }

        // Relative path
        return baseURL.appendingPathComponent(urlString).absoluteString
    }

    /// Validates connection to Homepage
    func validateConnection() async throws -> Bool {
        let (_, response) = try await InsecureURLSession.shared.data(from: baseURL)

        if let httpResponse = response as? HTTPURLResponse {
            return (200...299).contains(httpResponse.statusCode)
        }

        return false
    }
}

// MARK: - Parsed Data Models

struct ParsedService: Identifiable {
    let id: String
    let name: String
    let href: String?
    let iconURL: String?
    let description: String?
    let category: String?
    let sortOrder: Int
}

struct ParsedBookmark: Identifiable {
    let id: String
    let name: String
    let abbreviation: String?
    let href: String
    let category: String?
    let sortOrder: Int
}

// MARK: - Errors

enum HomepageError: LocalizedError {
    case invalidHTML
    case parsingFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidHTML:
            return "Could not decode Homepage HTML"
        case .parsingFailed(let message):
            return "Failed to parse Homepage: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

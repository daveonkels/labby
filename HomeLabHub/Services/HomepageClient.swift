import Foundation
import SwiftSoup

struct HomepageClient {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Fetches and parses services from Homepage HTML
    func fetchServices() async throws -> [ParsedService] {
        let (data, _) = try await URLSession.shared.data(from: baseURL)

        guard let html = String(data: data, encoding: .utf8) else {
            throw HomepageError.invalidHTML
        }

        return try parseHTML(html)
    }

    /// Parses Homepage HTML to extract services
    private func parseHTML(_ html: String) throws -> [ParsedService] {
        let document = try SwiftSoup.parse(html)
        var services: [ParsedService] = []

        // Debug: Print first 500 chars of HTML to see structure
        print("📄 [Homepage] HTML length: \(html.count) characters")

        // Homepage is a Next.js app - data is in __NEXT_DATA__ script tag
        if let nextDataScript = try? document.select("script#__NEXT_DATA__").first() {
            let jsonString = try nextDataScript.html()
            print("📄 [Homepage] Found __NEXT_DATA__, length: \(jsonString.count)")

            if let data = jsonString.data(using: .utf8) {
                let parsedFromNextData = try parseNextData(data)
                if !parsedFromNextData.isEmpty {
                    return parsedFromNextData
                }
            }
        } else {
            print("📄 [Homepage] No __NEXT_DATA__ found, trying DOM parsing...")
        }

        // Fallback: Try DOM-based parsing
        // Find all service groups (sections with service-group-name class)
        let groups = try document.select("h2.service-group-name, div.service-group-name")
        print("📄 [Homepage] Found \(groups.count) service groups")

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
            print("📄 [Homepage] No grouped services found, trying direct service lookup...")
            let serviceElements = try document.select("li.service, div.service, [class*='service-']")
            print("📄 [Homepage] Found \(serviceElements.count) service elements directly")

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

        print("📄 [Homepage] Total parsed services: \(services.count)")
        for service in services {
            print("📄 [Homepage]   - \(service.name): \(service.href ?? "no URL")")
        }

        return services
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

    /// Parse Next.js __NEXT_DATA__ JSON to extract services
    private func parseNextData(_ data: Data) throws -> [ParsedService] {
        var services: [ParsedService] = []

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let props = json["props"] as? [String: Any],
              let pageProps = props["pageProps"] as? [String: Any] else {
            print("📄 [Homepage] Could not parse __NEXT_DATA__ structure")
            return []
        }

        print("📄 [Homepage] pageProps keys: \(pageProps.keys)")

        // Homepage stores services in fallback["/api/services"]
        // Structure: [ { name: "GroupName", services: [ { name, href, icon, ... } ] } ]

        var serviceGroups: [[String: Any]]? = nil

        // Try fallback["/api/services"] first (SWR pattern)
        if let fallback = pageProps["fallback"] as? [String: Any] {
            print("📄 [Homepage] fallback keys: \(fallback.keys)")
            if let apiServices = fallback["/api/services"] as? [[String: Any]] {
                serviceGroups = apiServices
            }
        }

        // Fallback to direct services key
        if serviceGroups == nil {
            if let s = pageProps["services"] as? [[String: Any]] {
                serviceGroups = s
            }
        }

        guard let groups = serviceGroups else {
            print("📄 [Homepage] No services found in pageProps")
            return []
        }

        print("📄 [Homepage] Found \(groups.count) service groups")

        // Parse each service group
        for groupDict in groups {
            let groupName = groupDict["name"] as? String ?? "Other"
            guard let servicesList = groupDict["services"] as? [[String: Any]] else { continue }

            print("📄 [Homepage] Group '\(groupName)' has \(servicesList.count) services")

            for serviceInfo in servicesList {
                let serviceName = serviceInfo["name"] as? String ?? "Unknown"
                let href = serviceInfo["href"] as? String
                let icon = serviceInfo["icon"] as? String
                let description = serviceInfo["description"] as? String

                // Resolve icon URL
                var iconURL: String? = nil
                if let icon = icon {
                    if icon.hasPrefix("http") {
                        iconURL = icon
                    } else if icon.hasPrefix("/") {
                        iconURL = resolveURL(icon)
                    } else if icon.hasPrefix("si-") || icon.hasPrefix("mdi-") {
                        // Simple Icons or Material Design Icons - skip for now
                        iconURL = nil
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
                print("📄 [Homepage]   Parsed: \(serviceName) -> \(href ?? "no URL")")
            }
        }

        print("📄 [Homepage] Total parsed from __NEXT_DATA__: \(services.count)")
        return services
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
        let (_, response) = try await URLSession.shared.data(from: baseURL)

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

import Foundation
import SwiftData
import UniformTypeIdentifiers
import CoreTransferable

@Model
final class Service {
    var id: UUID
    var name: String
    var urlString: String
    var iconURLString: String?
    var iconSFSymbol: String?
    var category: String?
    var sortOrder: Int
    var isManuallyAdded: Bool
    var lastHealthCheck: Date?
    var isHealthy: Bool?
    var homepageServiceId: String?
    var trustSelfSignedCertificates: Bool

    var url: URL? {
        URL(string: urlString)
    }

    var iconURL: URL? {
        guard let iconURLString else { return nil }
        return URL(string: iconURLString)
    }

    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        iconURLString: String? = nil,
        iconSFSymbol: String? = nil,
        category: String? = nil,
        sortOrder: Int = 0,
        isManuallyAdded: Bool = false,
        homepageServiceId: String? = nil,
        trustSelfSignedCertificates: Bool = true
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.iconURLString = iconURLString
        self.iconSFSymbol = iconSFSymbol
        self.category = category
        self.sortOrder = sortOrder
        self.isManuallyAdded = isManuallyAdded
        self.homepageServiceId = homepageServiceId
        self.trustSelfSignedCertificates = trustSelfSignedCertificates
        self.lastHealthCheck = nil
        self.isHealthy = nil
    }
}

// MARK: - Drag and Drop Support

/// Lightweight transferable wrapper for Service drag and drop
/// Only carries the service ID - actual service is looked up in modelContext on drop
struct ServiceTransfer: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .serviceTransfer)
    }
}

extension UTType {
    static let serviceTransfer = UTType(exportedAs: "com.labby.service-transfer")
}

extension Service {
    static var preview: Service {
        Service(
            name: "Plex",
            urlString: "http://192.168.1.100:32400",
            iconSFSymbol: "play.tv",
            category: "Media"
        )
    }

    static var previewServices: [Service] {
        [
            Service(name: "Plex", urlString: "http://192.168.1.100:32400", iconSFSymbol: "play.tv", category: "Media", sortOrder: 0),
            Service(name: "Jellyfin", urlString: "http://192.168.1.100:8096", iconSFSymbol: "film", category: "Media", sortOrder: 1),
            Service(name: "Sonarr", urlString: "http://192.168.1.100:8989", iconSFSymbol: "tv", category: "Downloads", sortOrder: 2),
            Service(name: "Radarr", urlString: "http://192.168.1.100:7878", iconSFSymbol: "movieclapper", category: "Downloads", sortOrder: 3),
            Service(name: "Home Assistant", urlString: "http://192.168.1.100:8123", iconSFSymbol: "house", category: "Automation", sortOrder: 4),
            Service(name: "Proxmox", urlString: "https://192.168.1.50:8006", iconSFSymbol: "server.rack", category: "Infrastructure", sortOrder: 5)
        ]
    }
}

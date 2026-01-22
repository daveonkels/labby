import Foundation
import SwiftData

@Model
final class HomepageConnection {
    var id: UUID
    var baseURLString: String
    var name: String
    var lastSync: Date?
    var syncEnabled: Bool
    var trustSelfSignedCertificates: Bool
    var createdAt: Date
    /// Username for HTTP Basic Auth (password stored in Keychain)
    var username: String?

    var baseURL: URL? {
        URL(string: baseURLString)
    }

    /// Whether this connection has authentication configured
    var hasAuthentication: Bool {
        username != nil && !username!.isEmpty
    }

    init(
        id: UUID = UUID(),
        baseURLString: String,
        name: String = "My Homepage",
        syncEnabled: Bool = true,
        trustSelfSignedCertificates: Bool = true,
        username: String? = nil
    ) {
        self.id = id
        self.baseURLString = baseURLString
        self.name = name
        self.syncEnabled = syncEnabled
        self.trustSelfSignedCertificates = trustSelfSignedCertificates
        self.username = username
        self.createdAt = Date()
        self.lastSync = nil
    }
}

extension HomepageConnection {
    static var preview: HomepageConnection {
        HomepageConnection(
            baseURLString: "http://192.168.1.100:3000",
            name: "Home Server"
        )
    }
}

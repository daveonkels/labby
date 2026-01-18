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

    var baseURL: URL? {
        URL(string: baseURLString)
    }

    init(
        id: UUID = UUID(),
        baseURLString: String,
        name: String = "My Homepage",
        syncEnabled: Bool = true,
        trustSelfSignedCertificates: Bool = true
    ) {
        self.id = id
        self.baseURLString = baseURLString
        self.name = name
        self.syncEnabled = syncEnabled
        self.trustSelfSignedCertificates = trustSelfSignedCertificates
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

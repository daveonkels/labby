import Foundation
import SwiftData

@Model
final class Bookmark {
    var id: UUID
    var name: String
    var abbreviation: String?
    var urlString: String
    var category: String?
    var sortOrder: Int
    var homepageBookmarkId: String?

    var url: URL? {
        URL(string: urlString)
    }

    init(
        id: UUID = UUID(),
        name: String,
        abbreviation: String? = nil,
        urlString: String,
        category: String? = nil,
        sortOrder: Int = 0,
        homepageBookmarkId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.abbreviation = abbreviation
        self.urlString = urlString
        self.category = category
        self.sortOrder = sortOrder
        self.homepageBookmarkId = homepageBookmarkId
    }
}

extension Bookmark {
    static var preview: Bookmark {
        Bookmark(
            name: "GitHub",
            abbreviation: "GH",
            urlString: "https://github.com",
            category: "Developer"
        )
    }
}

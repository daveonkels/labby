import Foundation
import SwiftData

/// Stores user's custom icon preference for a category
@Model
final class CategoryIconPreference {
    /// The category name (case-insensitive matching)
    @Attribute(.unique) var categoryName: String

    /// The SF Symbol name chosen by the user
    var iconName: String

    /// When this preference was last updated
    var updatedAt: Date

    init(categoryName: String, iconName: String) {
        self.categoryName = categoryName.lowercased()
        self.iconName = iconName
        self.updatedAt = Date()
    }
}

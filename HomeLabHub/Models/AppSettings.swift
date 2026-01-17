import Foundation
import SwiftData

enum BackgroundType: String, Codable {
    case gradient      // Default gradient orbs
    case customImage   // User-uploaded image
    case aiGenerated   // ImagePlayground generated
}

@Model
final class AppSettings {
    var id: UUID
    var backgroundType: BackgroundType
    var backgroundImageData: Data?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        backgroundType: BackgroundType = .gradient,
        backgroundImageData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.backgroundType = backgroundType
        self.backgroundImageData = backgroundImageData
        self.createdAt = createdAt
    }

    /// Returns the background image if available
    var backgroundImage: Data? {
        guard backgroundType != .gradient else { return nil }
        return backgroundImageData
    }

    /// Updates the background with a custom image
    func setCustomImage(_ imageData: Data, type: BackgroundType = .customImage) {
        self.backgroundType = type
        self.backgroundImageData = imageData
    }

    /// Resets to default gradient background
    func resetToDefault() {
        self.backgroundType = .gradient
        self.backgroundImageData = nil
    }
}

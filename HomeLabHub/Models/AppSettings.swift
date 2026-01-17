import Foundation
import SwiftData
import SwiftUI

enum BackgroundType: String, Codable {
    case gradient      // Gradient preset
    case customImage   // User-uploaded image
    case aiGenerated   // ImagePlayground generated
}

enum GradientPreset: String, Codable, CaseIterable {
    case `default`
    case sunset
    case ocean
    case forest
    case twilight
    case aurora
    case ember
    case midnight
    case rose
    case slate
    case lavender
    case mint

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .sunset: return "Sunset"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .twilight: return "Twilight"
        case .aurora: return "Aurora"
        case .ember: return "Ember"
        case .midnight: return "Midnight"
        case .rose: return "Rose"
        case .slate: return "Slate"
        case .lavender: return "Lavender"
        case .mint: return "Mint"
        }
    }

    var colors: [Color] {
        switch self {
        case .default:
            return [.green, .blue]
        case .sunset:
            return [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.95, green: 0.4, blue: 0.5), Color(red: 0.6, green: 0.3, blue: 0.7)]
        case .ocean:
            return [Color(red: 0.1, green: 0.2, blue: 0.5), Color(red: 0.1, green: 0.5, blue: 0.6), Color(red: 0.2, green: 0.7, blue: 0.8)]
        case .forest:
            return [Color(red: 0.1, green: 0.3, blue: 0.2), Color(red: 0.2, green: 0.5, blue: 0.4)]
        case .twilight:
            return [Color(red: 0.4, green: 0.2, blue: 0.6), Color(red: 0.2, green: 0.2, blue: 0.5), Color(red: 0.1, green: 0.3, blue: 0.6)]
        case .aurora:
            return [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.2, green: 0.6, blue: 0.7), Color(red: 0.5, green: 0.3, blue: 0.7)]
        case .ember:
            return [Color(red: 0.8, green: 0.2, blue: 0.1), Color(red: 1.0, green: 0.5, blue: 0.2), Color(red: 1.0, green: 0.8, blue: 0.3)]
        case .midnight:
            return [Color(red: 0.05, green: 0.1, blue: 0.2), Color(red: 0.1, green: 0.15, blue: 0.3)]
        case .rose:
            return [Color(red: 0.95, green: 0.5, blue: 0.6), Color(red: 0.85, green: 0.3, blue: 0.6), Color(red: 0.6, green: 0.2, blue: 0.6)]
        case .slate:
            return [Color(red: 0.3, green: 0.35, blue: 0.4), Color(red: 0.4, green: 0.45, blue: 0.5), Color(red: 0.5, green: 0.55, blue: 0.6)]
        case .lavender:
            return [Color(red: 0.7, green: 0.6, blue: 0.9), Color(red: 0.9, green: 0.7, blue: 0.85)]
        case .mint:
            return [Color(red: 0.6, green: 0.9, blue: 0.8), Color(red: 0.3, green: 0.7, blue: 0.7)]
        }
    }

    var isRadial: Bool {
        switch self {
        case .default, .ember, .midnight, .lavender:
            return true
        default:
            return false
        }
    }
}

@Model
final class AppSettings {
    var id: UUID
    var backgroundType: BackgroundType
    var backgroundImageData: Data?
    var gradientPresetRaw: String = GradientPreset.default.rawValue
    var createdAt: Date

    var gradientPreset: GradientPreset {
        get { GradientPreset(rawValue: gradientPresetRaw) ?? .default }
        set { gradientPresetRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        backgroundType: BackgroundType = .gradient,
        backgroundImageData: Data? = nil,
        gradientPreset: GradientPreset = .default,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.backgroundType = backgroundType
        self.backgroundImageData = backgroundImageData
        self.gradientPresetRaw = gradientPreset.rawValue
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

    /// Sets the gradient preset
    func setGradientPreset(_ preset: GradientPreset) {
        self.backgroundType = .gradient
        self.gradientPreset = preset
        self.backgroundImageData = nil
    }

    /// Resets to default gradient background
    func resetToDefault() {
        self.backgroundType = .gradient
        self.gradientPreset = .default
        self.backgroundImageData = nil
    }
}

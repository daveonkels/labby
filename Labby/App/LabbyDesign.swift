import SwiftUI

// MARK: - Hex Color Extension

extension Color {
    /// Initialize a Color from a hex string (supports 3, 6, and 8 character formats)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Labby Design System Colors

/// Retro CRT Monitor / Hacker Terminal color palette
/// - Dark Mode ("The Glow"): Mimics glowing phosphor on a black screen
/// - Light Mode ("The Chip"): Mimics a physical circuit board
struct LabbyColors {
    // MARK: Dark Mode - "The Glow"

    /// Primary tint for dark mode - bright phosphor green
    static let darkPrimary = Color(hex: "4AF626")

    /// Button gradient start (top) - Phosphor Neon
    static let darkGradientStart = Color(hex: "4AF626")

    /// Button gradient end (bottom) - Deep Phosphor
    static let darkGradientEnd = Color(hex: "28C740")

    // MARK: Light Mode - "The Chip"

    /// Primary tint for light mode - circuit board green
    static let lightPrimary = Color(hex: "008F11")

    /// Button gradient start (top-leading) - Fresh Green
    static let lightGradientStart = Color(hex: "2EBD59")

    /// Button gradient end (bottom-trailing) - Circuit Green
    static let lightGradientEnd = Color(hex: "008F11")

    // MARK: Adaptive Colors

    /// Returns the appropriate primary color for the current color scheme
    static func primary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkPrimary : lightPrimary
    }

    /// Returns the appropriate gradient colors for the current color scheme
    static func gradientColors(for colorScheme: ColorScheme) -> [Color] {
        colorScheme == .dark
            ? [darkGradientStart, darkGradientEnd]
            : [lightGradientStart, lightGradientEnd]
    }
}

// MARK: - Labby Primary Button

/// A retro CRT-styled button component that adapts to system theme
///
/// - Dark Mode: Glowing phosphor aesthetic with green glow and grid border
/// - Light Mode: Solid circuit chip aesthetic with diagonal gradient
struct LabbyButton: View {
    var title: String
    var icon: String?
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(buttonBorder)
            .shadow(
                color: colorScheme == .dark ? LabbyColors.darkPrimary.opacity(0.4) : .clear,
                radius: 8,
                x: 0,
                y: 0
            )
        }
    }

    private var buttonBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: LabbyColors.gradientColors(for: colorScheme)),
            startPoint: colorScheme == .dark ? .top : .topLeading,
            endPoint: colorScheme == .dark ? .bottom : .bottomTrailing
        )
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                LabbyColors.darkPrimary.opacity(0.3),
                lineWidth: colorScheme == .dark ? 1 : 0
            )
    }
}

// MARK: - Labby Secondary Button

/// A secondary button style for less prominent actions
struct LabbySecondaryButton: View {
    var title: String
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(LabbyColors.primary(for: colorScheme))
        }
    }
}

// MARK: - Preview

#Preview("Labby Buttons") {
    VStack(spacing: 24) {
        VStack(spacing: 16) {
            Text("Dark Mode")
                .font(.headline)
            LabbyButton(title: "Connect to Homepage", icon: "link") {}
            LabbySecondaryButton(title: "or add services manually") {}
        }
        .padding()
        .background(Color.black)
        .environment(\.colorScheme, .dark)

        VStack(spacing: 16) {
            Text("Light Mode")
                .font(.headline)
            LabbyButton(title: "Connect to Homepage", icon: "link") {}
            LabbySecondaryButton(title: "or add services manually") {}
        }
        .padding()
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
    .padding()
}

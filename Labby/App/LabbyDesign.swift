import SwiftUI

// MARK: - Retro Typography System

/// A ViewModifier that applies SF Mono (monospaced) font styling for the retro CRT aesthetic.
/// Use this for "structure" and "data" elements like headers, status text, and labels.
struct RetroFont: ViewModifier {
    var size: CGFloat?
    var weight: Font.Weight
    var relativeTo: Font.TextStyle

    init(weight: Font.Weight = .bold, size: CGFloat? = nil, relativeTo: Font.TextStyle = .body) {
        self.weight = weight
        self.size = size
        self.relativeTo = relativeTo
    }

    func body(content: Content) -> some View {
        content
            .font(.system(
                size: size ?? Self.defaultSize(for: relativeTo),
                weight: weight,
                design: .monospaced
            ))
    }

    /// Returns the default system font size for a given text style
    static func defaultSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .subheadline: return 15
        case .body: return 17
        case .callout: return 16
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }
}

extension View {
    /// Applies retro monospaced styling for the given text style
    /// - Parameters:
    ///   - style: The text style to base the size on
    ///   - weight: The font weight (default: .bold)
    func retroStyle(_ style: Font.TextStyle = .body, weight: Font.Weight = .bold) -> some View {
        modifier(RetroFont(weight: weight, relativeTo: style))
    }

    /// Applies retro monospaced styling with a specific size
    /// - Parameters:
    ///   - size: The exact font size to use
    ///   - weight: The font weight (default: .bold)
    func retroStyle(size: CGFloat, weight: Font.Weight = .bold) -> some View {
        modifier(RetroFont(weight: weight, size: size))
    }
}

// MARK: - Retro Section Header Style

/// A consistent section header style for settings-like lists
/// Displays uppercase monospaced text like a config file header
struct RetroSectionHeader: View {
    let title: String
    let icon: String?

    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
            }
            Text(title.uppercased())
                .tracking(0.5)
        }
        .font(.system(size: 11, weight: .heavy, design: .monospaced))
        .foregroundStyle(LabbyColors.primary(for: colorScheme))
    }
}

// MARK: - Homepage Info Component

/// Reusable view that explains what Homepage is and provides links to learn more
struct HomepageInfoView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Homepage is a free, open-source dashboard application for organizing and monitoring your self-hosted services. Labby syncs with Homepage to automatically import your services.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    openURL(URL(string: "https://gethomepage.dev")!)
                } label: {
                    Label("Website", systemImage: "globe")
                }

                Button {
                    openURL(URL(string: "https://github.com/gethomepage/homepage")!)
                } label: {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            .buttonStyle(.bordered)
            .tint(LabbyColors.primary(for: colorScheme))
        }
    }
}

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

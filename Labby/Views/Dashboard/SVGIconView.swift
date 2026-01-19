import SwiftUI

/// A view that renders simple SVG icons (like MDI icons) by parsing the SVG path data
/// and rendering it as a native SwiftUI shape.
struct SVGIconView: View {
    let url: URL
    let tintColor: Color

    @State private var pathData: String?
    @State private var isLoading = true
    @State private var loadFailed = false

    /// Extract color from URL fragment (e.g., #9333ea) if present
    private var effectiveColor: Color {
        if let fragment = url.fragment, !fragment.isEmpty {
            return Color(hex: fragment)
        }
        return tintColor
    }

    /// URL without fragment for fetching
    private var fetchURL: URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        return components?.url ?? url
    }

    var body: some View {
        Group {
            if let pathData = pathData {
                SVGPathShape(pathData: pathData)
                    .fill(effectiveColor)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                // Failed to load - show default icon
                Image(systemName: "app.fill")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await loadSVG()
        }
    }

    private func loadSVG() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: fetchURL)
            if let svgString = String(data: data, encoding: .utf8),
               let path = extractPathData(from: svgString) {
                await MainActor.run {
                    self.pathData = path
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.loadFailed = true
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.loadFailed = true
                self.isLoading = false
            }
        }
    }

    /// Extracts the path data (d attribute) from an SVG string
    private func extractPathData(from svg: String) -> String? {
        // Find the <path element first
        guard let pathStart = svg.range(of: "<path") else {
            return nil
        }

        // Search for d=" only within the path element (space before d to avoid matching "id=")
        let searchRange = pathStart.upperBound..<svg.endIndex
        guard let dAttrRange = svg.range(of: " d=\"", range: searchRange) else {
            return nil
        }

        // The path data starts right after d="
        let pathDataStart = dAttrRange.upperBound

        // Find the closing quote after the path data
        guard let closingQuote = svg[pathDataStart...].firstIndex(of: "\"") else {
            return nil
        }

        return String(svg[pathDataStart..<closingQuote])
    }
}

/// A SwiftUI Shape that renders an SVG path string
struct SVGPathShape: Shape {
    let pathData: String

    func path(in rect: CGRect) -> Path {
        let svgPath = parseSVGPath(pathData)
        // Scale the path to fit the rect (MDI icons are 24x24)
        let scale = min(rect.width, rect.height) / 24.0
        return svgPath.applying(CGAffineTransform(scaleX: scale, y: scale))
    }

    /// Parses an SVG path data string into a SwiftUI Path
    private func parseSVGPath(_ data: String) -> Path {
        var path = Path()
        var currentPoint = CGPoint.zero
        var startPoint = CGPoint.zero
        var lastCommand: Character = " "

        let commands = tokenizePath(data)
        var i = 0

        // Helper to safely get a Double from commands array
        func getDouble(at index: Int) -> Double? {
            guard index < commands.count else { return nil }
            return Double(commands[index])
        }

        while i < commands.count {
            let token = commands[i]

            // Check if token is a command letter or a number (implicit repeat)
            let command: Character
            if let firstChar = token.first, firstChar.isLetter {
                command = firstChar
                i += 1
            } else {
                // Implicit command repeat - use last command
                // M becomes L after first point, m becomes l
                if lastCommand == "M" {
                    command = "L"
                } else if lastCommand == "m" {
                    command = "l"
                } else {
                    command = lastCommand
                }
            }

            lastCommand = command

            switch command {
            case "M": // MoveTo (absolute)
                if let x = getDouble(at: i), let y = getDouble(at: i + 1) {
                    currentPoint = CGPoint(x: x, y: y)
                    startPoint = currentPoint
                    path.move(to: currentPoint)
                }
                i += 2

            case "m": // MoveTo (relative)
                if let dx = getDouble(at: i), let dy = getDouble(at: i + 1) {
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    startPoint = currentPoint
                    path.move(to: currentPoint)
                }
                i += 2

            case "L": // LineTo (absolute)
                if let x = getDouble(at: i), let y = getDouble(at: i + 1) {
                    currentPoint = CGPoint(x: x, y: y)
                    path.addLine(to: currentPoint)
                }
                i += 2

            case "l": // LineTo (relative)
                if let dx = getDouble(at: i), let dy = getDouble(at: i + 1) {
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    path.addLine(to: currentPoint)
                }
                i += 2

            case "H": // Horizontal LineTo (absolute)
                if let x = getDouble(at: i) {
                    currentPoint = CGPoint(x: x, y: currentPoint.y)
                    path.addLine(to: currentPoint)
                }
                i += 1

            case "h": // Horizontal LineTo (relative)
                if let dx = getDouble(at: i) {
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
                    path.addLine(to: currentPoint)
                }
                i += 1

            case "V": // Vertical LineTo (absolute)
                if let y = getDouble(at: i) {
                    currentPoint = CGPoint(x: currentPoint.x, y: y)
                    path.addLine(to: currentPoint)
                }
                i += 1

            case "v": // Vertical LineTo (relative)
                if let dy = getDouble(at: i) {
                    currentPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
                    path.addLine(to: currentPoint)
                }
                i += 1

            case "C": // CurveTo (absolute)
                if let x1 = getDouble(at: i), let y1 = getDouble(at: i + 1),
                   let x2 = getDouble(at: i + 2), let y2 = getDouble(at: i + 3),
                   let x = getDouble(at: i + 4), let y = getDouble(at: i + 5) {
                    let control1 = CGPoint(x: x1, y: y1)
                    let control2 = CGPoint(x: x2, y: y2)
                    currentPoint = CGPoint(x: x, y: y)
                    path.addCurve(to: currentPoint, control1: control1, control2: control2)
                }
                i += 6

            case "c": // CurveTo (relative)
                if let dx1 = getDouble(at: i), let dy1 = getDouble(at: i + 1),
                   let dx2 = getDouble(at: i + 2), let dy2 = getDouble(at: i + 3),
                   let dx = getDouble(at: i + 4), let dy = getDouble(at: i + 5) {
                    let control1 = CGPoint(x: currentPoint.x + dx1, y: currentPoint.y + dy1)
                    let control2 = CGPoint(x: currentPoint.x + dx2, y: currentPoint.y + dy2)
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    path.addCurve(to: currentPoint, control1: control1, control2: control2)
                }
                i += 6

            case "S": // Smooth CurveTo (absolute)
                if let x2 = getDouble(at: i), let y2 = getDouble(at: i + 1),
                   let x = getDouble(at: i + 2), let y = getDouble(at: i + 3) {
                    let control1 = currentPoint // Simplified - should reflect previous control point
                    let control2 = CGPoint(x: x2, y: y2)
                    currentPoint = CGPoint(x: x, y: y)
                    path.addCurve(to: currentPoint, control1: control1, control2: control2)
                }
                i += 4

            case "s": // Smooth CurveTo (relative)
                if let dx2 = getDouble(at: i), let dy2 = getDouble(at: i + 1),
                   let dx = getDouble(at: i + 2), let dy = getDouble(at: i + 3) {
                    let control1 = currentPoint // Simplified
                    let control2 = CGPoint(x: currentPoint.x + dx2, y: currentPoint.y + dy2)
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    path.addCurve(to: currentPoint, control1: control1, control2: control2)
                }
                i += 4

            case "Q": // Quadratic CurveTo (absolute)
                if let x1 = getDouble(at: i), let y1 = getDouble(at: i + 1),
                   let x = getDouble(at: i + 2), let y = getDouble(at: i + 3) {
                    let control = CGPoint(x: x1, y: y1)
                    currentPoint = CGPoint(x: x, y: y)
                    path.addQuadCurve(to: currentPoint, control: control)
                }
                i += 4

            case "q": // Quadratic CurveTo (relative)
                if let dx1 = getDouble(at: i), let dy1 = getDouble(at: i + 1),
                   let dx = getDouble(at: i + 2), let dy = getDouble(at: i + 3) {
                    let control = CGPoint(x: currentPoint.x + dx1, y: currentPoint.y + dy1)
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    path.addQuadCurve(to: currentPoint, control: control)
                }
                i += 4

            case "A": // Arc (absolute) - simplified, draws line to endpoint
                // Arc params: rx ry x-rotation large-arc sweep x y
                if let x = getDouble(at: i + 5), let y = getDouble(at: i + 6) {
                    currentPoint = CGPoint(x: x, y: y)
                    path.addLine(to: currentPoint)
                }
                i += 7

            case "a": // Arc (relative) - simplified, draws line to endpoint
                if let dx = getDouble(at: i + 5), let dy = getDouble(at: i + 6) {
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    path.addLine(to: currentPoint)
                }
                i += 7

            case "Z", "z": // ClosePath
                path.closeSubpath()
                currentPoint = startPoint

            default:
                // Unknown command - skip to avoid infinite loop
                break
            }
        }

        return path
    }

    /// Tokenizes an SVG path string into commands and numbers
    private func tokenizePath(_ data: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""

        for char in data {
            if char.isLetter {
                if !currentToken.isEmpty {
                    tokens.append(currentToken.trimmingCharacters(in: .whitespaces))
                    currentToken = ""
                }
                tokens.append(String(char))
            } else if char == "," || char == " " || char == "\n" || char == "\t" {
                if !currentToken.isEmpty {
                    tokens.append(currentToken.trimmingCharacters(in: .whitespaces))
                    currentToken = ""
                }
            } else if char == "-" && !currentToken.isEmpty && !currentToken.hasSuffix("e") {
                // Negative number starts a new token (unless it's an exponent)
                tokens.append(currentToken.trimmingCharacters(in: .whitespaces))
                currentToken = String(char)
            } else {
                currentToken.append(char)
            }
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken.trimmingCharacters(in: .whitespaces))
        }

        return tokens.filter { !$0.isEmpty }
    }
}

#Preview {
    VStack(spacing: 20) {
        SVGIconView(
            url: URL(string: "https://cdn.jsdelivr.net/npm/@mdi/svg@latest/svg/chat-processing.svg")!,
            tintColor: .purple
        )
        .frame(width: 48, height: 48)

        SVGIconView(
            url: URL(string: "https://cdn.jsdelivr.net/npm/@mdi/svg@latest/svg/home.svg")!,
            tintColor: .green
        )
        .frame(width: 48, height: 48)
    }
    .padding()
}

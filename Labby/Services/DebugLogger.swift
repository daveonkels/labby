import Foundation
import SwiftUI
import UIKit

/// A log entry for debugging
struct DebugLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String

    enum LogLevel: String {
        case info = "INFO"
        case debug = "DEBUG"
        case warning = "WARN"
        case error = "ERROR"

        var color: Color {
            switch self {
            case .info: return .primary
            case .debug: return .secondary
            case .warning: return .orange
            case .error: return .red
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .debug: return "ant"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }
    }
}

/// In-app debug logger for troubleshooting
@Observable
final class DebugLogger {
    static let shared = DebugLogger()

    private(set) var entries: [DebugLogEntry] = []
    private let maxEntries = 500
    private let queue = DispatchQueue(label: "com.labby.debuglogger")

    private init() {}

    func log(_ message: String, level: DebugLogEntry.LogLevel = .info, category: String = "General") {
        let entry = DebugLogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message
        )

        #if DEBUG
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        print("[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)")
        #endif

        queue.async { [weak self] in
            DispatchQueue.main.async {
                self?.entries.append(entry)
                // Trim old entries if needed
                if let count = self?.entries.count, count > self?.maxEntries ?? 500 {
                    self?.entries.removeFirst(count - (self?.maxEntries ?? 500))
                }
            }
        }
    }

    func info(_ message: String, category: String = "General") {
        log(message, level: .info, category: category)
    }

    func debug(_ message: String, category: String = "General") {
        log(message, level: .debug, category: category)
    }

    func warning(_ message: String, category: String = "General") {
        log(message, level: .warning, category: category)
    }

    func error(_ message: String, category: String = "General") {
        log(message, level: .error, category: category)
    }

    func clear() {
        entries.removeAll()
    }

    /// Export logs as a string for sharing
    func exportLogs() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        return entries.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
        }.joined(separator: "\n")
    }

    #if DEBUG
    func dumpWindowHierarchy(reason: String) {
        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            let windows = scenes.flatMap { $0.windows }
            let summary = windows.map { window -> String in
                let level = window.windowLevel.rawValue
                let hidden = window.isHidden ? "hidden" : "visible"
                let alpha = String(format: "%.2f", window.alpha)
                let root = String(describing: type(of: window.rootViewController))
                return "level=\(level) \(hidden) alpha=\(alpha) root=\(root)"
            }
            self.debug("Window dump (\(reason)): count=\(windows.count) [\(summary.joined(separator: " | "))]", category: "Window")
        }
    }
    #endif
}

#if DEBUG
final class GlobalTouchLogger: NSObject, UIGestureRecognizerDelegate {
    static let shared = GlobalTouchLogger()
    private var installedWindows: Set<ObjectIdentifier> = []

    func install() {
        installOnAllWindows()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowNotification),
            name: UIWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowNotification),
            name: UIScene.didActivateNotification,
            object: nil
        )
    }

    @objc private func handleWindowNotification() {
        installOnAllWindows()
    }

    private func installOnAllWindows() {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        for window in windows {
            let identifier = ObjectIdentifier(window)
            guard !installedWindows.contains(identifier) else { continue }
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            installedWindows.insert(identifier)
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let window = recognizer.view as? UIWindow else { return }
        let location = recognizer.location(in: window)
        DebugLogger.shared.debug(
            "Global tap at (\(Int(location.x)), \(Int(location.y))) windowLevel=\(window.windowLevel.rawValue)",
            category: "GlobalTouch"
        )
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
#endif

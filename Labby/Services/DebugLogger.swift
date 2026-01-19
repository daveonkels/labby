import Foundation
import SwiftUI

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
}

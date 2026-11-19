import Foundation
import os.log

final class AppLog {

    static let shared = AppLog()

    private let log: OSLog
    private var entries: [Entry] = []
    private let lock = NSLock()
    private let maxEntries = 5000

    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: Level
        let category: String
        let message: String
    }

    enum Level: String {
        case debug
        case info
        case warning
        case error
        case fault
    }

    private init() {
        log = OSLog(subsystem: "_013", category: "App")
    }

    func debug(_ message: String, category: String = "App") {
        append(level: .debug, category: category, message: message)
        os_log(.debug, log: log, "%{public}s", message)
    }

    func info(_ message: String, category: String = "App") {
        append(level: .info, category: category, message: message)
        os_log(.info, log: log, "%{public}s", message)
    }

    func warning(_ message: String, category: String = "App") {
        append(level: .warning, category: category, message: message)
        os_log(.default, log: log, "%{public}s", message)
    }

    func error(_ message: String, category: String = "App") {
        append(level: .error, category: category, message: message)
        os_log(.error, log: log, "%{public}s", message)
    }

    func fault(_ message: String, category: String = "App") {
        append(level: .fault, category: category, message: message)
        os_log(.fault, log: log, "%{public}s", message)
    }

    func allEntries() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    func entries(level: Level) -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries.filter { $0.level == level }
    }

    func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    func export() -> Data {
        let lines = allEntries().map { entry in
            let ts = ISO8601DateFormatter().string(from: entry.timestamp)
            return "[\(ts)] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
        }
        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    private func append(level: Level, category: String, message: String) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(Entry(timestamp: Date(), level: level, category: category, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}

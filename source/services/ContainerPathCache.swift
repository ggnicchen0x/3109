import Foundation

final class ContainerPathCache: Codable {

    struct Entry: Codable {
        let bundleID: String
        let containerType: ContainerType
        let path: String
        let resolvedAt: Date
    }

    enum ContainerType: String, Codable {
        case data
        case bundle
        case group
    }

    private enum CodingKeys: String, CodingKey {
        case entries
    }

    private var entries: [String: Entry] = [:]
    private let lock = NSRecursiveLock()

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = try container.decode([String: Entry].self, forKey: .entries)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entries, forKey: .entries)
    }

    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("container_paths.json")
    }

    static func load() -> ContainerPathCache {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(ContainerPathCache.self, from: data) else {
            return ContainerPathCache()
        }
        return cache
    }

    func save() {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.cacheURL, options: .atomic)
    }

    func path(for bundleID: String, type: ContainerType) -> String? {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(bundleID):\(type.rawValue)"
        return entries[key]?.path
    }

    func store(bundleID: String, type: ContainerType, path: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(bundleID):\(type.rawValue)"
        entries[key] = Entry(
            bundleID: bundleID, containerType: type,
            path: path, resolvedAt: Date()
        )
    }

    func remove(bundleID: String, type: ContainerType) {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(bundleID):\(type.rawValue)"
        entries.removeValue(forKey: key)
    }

    func allEntries() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return Array(entries.values)
    }

    func purgeStale(olderThan interval: TimeInterval = 86400) {
        lock.lock()
        defer { lock.unlock() }
        let cutoff = Date().addingTimeInterval(-interval)
        entries = entries.filter { $0.value.resolvedAt > cutoff }
    }

    func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    func resolve(bundleID: String, type: ContainerType) -> String? {
        if let cached = path(for: bundleID, type: type) {
            if FileManager.default.fileExists(atPath: cached) {
                return cached
            }
            remove(bundleID: bundleID, type: type)
        }
        guard let resolved = MCMBridge.containerPath(forBundleID: bundleID, type: type) else {
            return nil
        }
        store(bundleID: bundleID, type: type, path: resolved)
        save()
        return resolved
    }
}

enum MCMBridge {
    static func containerPath(forBundleID bundleID: String, type: ContainerPathCache.ContainerType) -> String? {
        switch type {
        case .data:
            var path: UnsafeMutablePointer<CChar>?
            let rc = mcm_get_container_url(bundleID, 0, &path)
            guard rc == 0, let p = path else { return nil }
            defer { free(p) }
            return String(cString: p)
        case .bundle:
            var path: UnsafeMutablePointer<CChar>?
            let rc = mcm_get_container_url(bundleID, 1, &path)
            guard rc == 0, let p = path else { return nil }
            defer { free(p) }
            return String(cString: p)
        case .group:
            var path: UnsafeMutablePointer<CChar>?
            let rc = mcm_get_container_url(bundleID, 2, &path)
            guard rc == 0, let p = path else { return nil }
            defer { free(p) }
            return String(cString: p)
        }
    }
}

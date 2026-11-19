import Foundation

enum SQLiteSidecarPolicy {

    static let sidecarExtensions = ["wal", "shm", "journal"]

    static func sidecarURLs(for databaseURL: URL) -> [URL] {
        let base = databaseURL.path
        return sidecarExtensions.map { ext in
            URL(fileURLWithPath: base + "-" + ext)
        }
    }

    static func existingSidecars(for databaseURL: URL) -> [URL] {
        sidecarURLs(for: databaseURL).filter {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    static func totalSize(for databaseURL: URL) -> Int64 {
        var total: Int64 = 0
        let fm = FileManager.default

        if let attrs = try? fm.attributesOfItem(atPath: databaseURL.path),
           let size = attrs[.size] as? Int64 {
            total += size
        }

        for sidecar in existingSidecars(for: databaseURL) {
            if let attrs = try? fm.attributesOfItem(atPath: sidecar.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }

        return total
    }

    static func copySafely(from source: URL, to destination: URL) throws {
        let fm = FileManager.default

        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)

        for ext in sidecarExtensions {
            let srcSidecar = URL(fileURLWithPath: source.path + "-" + ext)
            let dstSidecar = URL(fileURLWithPath: destination.path + "-" + ext)
            if fm.fileExists(atPath: srcSidecar.path) {
                if fm.fileExists(atPath: dstSidecar.path) {
                    try fm.removeItem(at: dstSidecar)
                }
                try fm.copyItem(at: srcSidecar, to: dstSidecar)
            }
        }
    }

    static func removeSafely(at url: URL) throws {
        let fm = FileManager.default
        try? fm.removeItem(at: url)
        for sidecar in sidecarURLs(for: url) {
            try? fm.removeItem(at: sidecar)
        }
    }
}

enum SQLiteIntegrityService {

    static func check(databaseURL: URL) -> IntegrityResult {
        do {
            let reader = try SQLiteReader(url: databaseURL)
            let result = try reader.integrityCheck()
            if result == "ok" {
                return .ok
            }
            return .corruption(result)
        } catch {
            return .unreadable(error.localizedDescription)
        }
    }

    enum IntegrityResult {
        case ok
        case corruption(String)
        case unreadable(String)

        var isOK: Bool {
            if case .ok = self { return true }
            return false
        }
    }
}

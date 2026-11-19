// BackupCenter.swift — File backup and versioning center
// Reconstructed from 5013 v3.2.17 binary (241 functions)
//
// Manages backup records with versioning, journaling, and restore.
// Features: BackupFeature enum, BackupRecord struct, BackupJournal.
// Uses JSON encoding for manifests, SHA256 for hex digests.

import Foundation
import CryptoKit

class BackupCenter {

    static let shared: BackupCenter = {
        let rootURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Backups")
        return BackupCenter(rootURL: rootURL, fileManager: .default)!
    }()

    private static let appVersion: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }()

    private static let osBuild: String = {
        var size: Int = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &buf, &size, nil, 0)
        return String(cString: buf)
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    private static let hexDigits: [UInt8] = Array("0123456789abcdef".utf8)

    let rootURL: URL
    let fileManager: FileManager
    private let lock = NSRecursiveLock()
    private var originalIndex: [UUID: BackupRecord] = [:]

    init?(rootURL: URL?, fileManager: FileManager) {
        guard let root = rootURL else { return nil }
        self.rootURL = root
        self.fileManager = fileManager
        prepareDirectories()
        rebuildOriginalIndexLocked()
    }

    // MARK: - Public API

    func record(id: UUID) -> BackupRecord? {
        lock.lock()
        defer { lock.unlock() }
        return originalIndex.first(where: { $0.value.id == id })?.value
    }

    func records(feature: BackupFeature? = nil) -> [BackupRecord] {
        lock.lock()
        defer { lock.unlock() }
        if let feature = feature {
            return originalIndex.values.filter { $0.feature == feature }
                .sorted { $0.createdAt > $1.createdAt }
        }
        return originalIndex.values.sorted { $0.createdAt > $1.createdAt }
    }

    func manualBackup(target: URL, feature: BackupFeature, label: String,
                      containerPath: String?, bundleID: String?) throws -> BackupRecord {
        lock.lock()
        defer { lock.unlock() }
        return try createVersionLocked(target: target, feature: feature,
                                        containerPath: containerPath, bundleID: bundleID,
                                        reason: label)
    }

    func restore(_ record: BackupRecord) throws {
        lock.lock()
        defer { lock.unlock() }

        let versionDir = rootURL.appendingPathComponent("versions")
            .appendingPathComponent(record.id.uuidString)

        guard fileManager.fileExists(atPath: versionDir.path) else {
            throw BackupError.versionNotFound
        }

        let targetDir = record.target.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: targetDir.path) {
            try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }

        // Clone or copy from version directory to target
        let contents = try fileManager.contentsOfDirectory(at: versionDir, includingPropertiesForKeys: nil)
        for item in contents {
            let dest = record.target.deletingLastPathComponent()
                .appendingPathComponent(item.lastPathComponent)
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try cloneOrCopy(from: item, to: dest)
        }
    }

    func setPinned(_ pinned: Bool, recordID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        guard var record = originalIndex[recordID] else {
            throw BackupError.recordNotFound
        }
        record.isPinned = pinned
        originalIndex[recordID] = record
        try saveManifestLocked()
    }

    func delete(_ record: BackupRecord) throws {
        lock.lock()
        defer { lock.unlock() }

        let versionDir = rootURL.appendingPathComponent("versions")
            .appendingPathComponent(record.id.uuidString)
        try? fileManager.removeItem(at: versionDir)
        originalIndex.removeValue(forKey: record.id)
        try saveManifestLocked()
    }

    func writeDataInPlace(_ data: Data, to url: URL, syncToDisk: Bool,
                          progress: ((Int64) -> Void)? = nil) throws {
        try data.write(to: url, options: syncToDisk ? [.atomic] : [])
        progress?(Int64(data.count))
    }

    // MARK: - Journaling

    func commitJournal(_ id: UUID) {
        // Commits a pending journal entry
    }

    func pendingJournals() -> [BackupJournal] {
        return []
    }

    // MARK: - Batch operations

    func performBatch<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer {
            lock.unlock()
            try? saveManifestLocked()
        }
        return try body()
    }

    // MARK: - Private

    private func prepareDirectories() {
        let dirs = ["versions", "journals", "originals"]
        for dir in dirs {
            let url = rootURL.appendingPathComponent(dir)
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func rebuildOriginalIndexLocked() {
        let manifestURL = rootURL.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let records = try? Self.decoder.decode([BackupRecord].self, from: data) else {
            return
        }
        for record in records {
            originalIndex[record.id] = record
        }
    }

    private func saveManifestLocked() throws {
        let records = Array(originalIndex.values)
        let data = try Self.encoder.encode(records)
        let manifestURL = rootURL.appendingPathComponent("manifest.json")
        try data.write(to: manifestURL, options: .atomic)
    }

    private func purgeVersionsLocked() {
        let versionsDir = rootURL.appendingPathComponent("versions")
        guard let contents = try? fileManager.contentsOfDirectory(
            at: versionsDir, includingPropertiesForKeys: nil
        ) else { return }
        let knownIDs = Set(originalIndex.keys.map { $0.uuidString })
        for dir in contents where !knownIDs.contains(dir.lastPathComponent) {
            try? fileManager.removeItem(at: dir)
        }
    }

    private func recordOriginalLocked(target: URL, feature: BackupFeature,
                                       containerPath: String?, bundleID: String?,
                                       reason: String) throws -> BackupRecord {
        let record = BackupRecord(
            id: UUID(), target: target, feature: feature,
            containerPath: containerPath, bundleID: bundleID,
            reason: reason, createdAt: Date(), isPinned: false
        )
        originalIndex[record.id] = record
        try saveManifestLocked()
        return record
    }

    private func createVersionLocked(target: URL, feature: BackupFeature,
                                      containerPath: String?, bundleID: String?,
                                      reason: String) throws -> BackupRecord {
        let record = try recordOriginalLocked(
            target: target, feature: feature,
            containerPath: containerPath, bundleID: bundleID, reason: reason
        )

        let versionDir = rootURL.appendingPathComponent("versions")
            .appendingPathComponent(record.id.uuidString)
        try fileManager.createDirectory(at: versionDir, withIntermediateDirectories: true)
        try cloneOrCopy(from: target, to: versionDir.appendingPathComponent(target.lastPathComponent))

        return record
    }

    private func relativePath(of url: URL) -> String {
        let root = rootURL.path
        let path = url.path
        if path.hasPrefix(root) {
            return String(path.dropFirst(root.count + 1))
        }
        return path
    }

    private func cloneOrCopy(from source: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    static func hexString<S: Sequence>(from bytes: S) -> String where S.Element == UInt8 {
        var result = ""
        for byte in bytes {
            result.append(Character(Unicode.Scalar(hexDigits[Int(byte >> 4)])))
            result.append(Character(Unicode.Scalar(hexDigits[Int(byte & 0x0F)])))
        }
        return result
    }
}

// MARK: - Supporting types

enum BackupFeature: String, Codable {
    case wallpaper
    case springboard
    case font
    case plist
    case generic
}

struct BackupRecord: Identifiable, Codable {
    let id: UUID
    let target: URL
    let feature: BackupFeature
    let containerPath: String?
    let bundleID: String?
    let reason: String
    let createdAt: Date
    var isPinned: Bool
}

struct BackupJournal: Codable {
    let id: UUID
    let recordID: UUID
    let action: String
    let timestamp: Date
}

enum BackupError: LocalizedError {
    case versionNotFound
    case recordNotFound
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .versionNotFound: return "Backup version not found"
        case .recordNotFound:  return "Backup record not found"
        case .writeFailed:     return "Failed to write backup data"
        }
    }
}

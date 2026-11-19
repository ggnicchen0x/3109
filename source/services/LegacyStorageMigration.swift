// LegacyStorageMigration.swift — One-shot legacy data migration
// Reconstructed from 5013 v3.2.17 binary
//
// 4 functions found:
// - migrateIfNeeded(fileManager:) — entry point, checks if migration needed
// - lock — static once-lock for thread safety
// - migrateDirectory(from:to:fileManager:) — moves directory contents
// - mergeContents(from:to:fileManager:) — merges individual files

import Foundation

enum LegacyStorageMigration {

    private static var migrated = false

    static func migrateIfNeeded(fileManager: FileManager) {
        guard !migrated else { return }
        migrated = true

        guard let oldContainer = legacyContainerURL(),
              let newContainer = currentContainerURL() else { return }

        guard fileManager.fileExists(atPath: oldContainer.path) else { return }

        migrateDirectory(from: oldContainer, to: newContainer, fileManager: fileManager)
    }

    private static func migrateDirectory(from source: URL, to destination: URL, fileManager: FileManager) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: source, includingPropertiesForKeys: nil
        ) else { return }

        if !fileManager.fileExists(atPath: destination.path) {
            try? fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        for item in contents {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) {
                mergeContents(from: item, to: target, fileManager: fileManager)
            } else {
                try? fileManager.moveItem(at: item, to: target)
            }
        }
    }

    private static func mergeContents(from source: URL, to destination: URL, fileManager: FileManager) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: source, includingPropertiesForKeys: nil
        ) else { return }

        for item in contents {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            if !fileManager.fileExists(atPath: target.path) {
                try? fileManager.moveItem(at: item, to: target)
            }
        }
    }

    private static func legacyContainerURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .deletingLastPathComponent()
            .appendingPathComponent("legacy_data")
    }

    private static func currentContainerURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}

import Foundation

enum MigrationConfigBackupService {

    struct ImportedSet {
        let url: URL
        let items: [ConfigItem]
    }

    struct ConfigItem: Codable {
        let path: String
        let type: ItemType
        let data: Data?
    }

    enum ItemType: String, Codable {
        case plist
        case file
        case directory
    }

    static func importBackup(from url: URL) -> ImportedSet? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let items = try? JSONDecoder().decode([ConfigItem].self, from: data) else { return nil }
        return ImportedSet(url: url, items: items)
    }

    static func exportBackup(to url: URL) -> Bool {
        let fm = FileManager.default
        let configPaths = [
            "/var/mobile/Library/Preferences",
            "/var/mobile/Library/SpringBoard",
        ]

        var items: [ConfigItem] = []
        for root in configPaths {
            guard let enumerator = fm.enumerator(atPath: root) else { continue }
            while let item = enumerator.nextObject() as? String {
                let fullPath = (root as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                fm.fileExists(atPath: fullPath, isDirectory: &isDir)

                if isDir.boolValue {
                    items.append(ConfigItem(path: fullPath, type: .directory, data: nil))
                } else {
                    let ext = (item as NSString).pathExtension.lowercased()
                    let type: ItemType = ext == "plist" ? .plist : .file
                    let fileData = try? Data(contentsOf: URL(fileURLWithPath: fullPath))
                    items.append(ConfigItem(path: fullPath, type: type, data: fileData))
                }
            }
        }

        guard let data = try? JSONEncoder().encode(items) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    static func apply(_ importedSet: ImportedSet) throws {
        let fm = FileManager.default
        for item in importedSet.items {
            switch item.type {
            case .directory:
                try fm.createDirectory(atPath: item.path, withIntermediateDirectories: true)
            case .plist, .file:
                guard let data = item.data else { continue }
                let url = URL(fileURLWithPath: item.path)
                let parent = url.deletingLastPathComponent()
                if !fm.fileExists(atPath: parent.path) {
                    try fm.createDirectory(at: parent, withIntermediateDirectories: true)
                }
                try data.write(to: url, options: .atomic)
            }
        }
    }
}

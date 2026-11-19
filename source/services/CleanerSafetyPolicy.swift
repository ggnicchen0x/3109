import Foundation

enum CleanerSafetyPolicy {

    enum Risk {
        case safe
        case needsBackup
        case destructive
    }

    static func risk(for path: String) -> Risk {
        let lower = path.lowercased()

        // System-critical paths
        let destructive = [
            "/var/mobile/library/preferences/com.apple.",
            "/var/containers/shared/systemgroup",
            "/var/mobile/library/caches/com.apple.",
            "/private/var/db",
            "/var/keybags",
            "/var/mobile/library/accounts",
        ]
        for prefix in destructive {
            if lower.hasPrefix(prefix) { return .destructive }
        }

        // Paths that should be backed up first
        let backup = [
            "/var/mobile/library/springboard",
            "/var/mobile/library/wallpaper",
            "/var/mobile/library/preferences",
            "/var/mobile/library/fonts",
        ]
        for prefix in backup {
            if lower.hasPrefix(prefix) { return .needsBackup }
        }

        return .safe
    }

    static func isSystemProtected(_ path: String) -> Bool {
        risk(for: path) == .destructive
    }

    static func requiresBackup(_ path: String) -> Bool {
        risk(for: path) == .needsBackup
    }

    static func allowedForDeletion(_ path: String) -> Bool {
        let lower = path.lowercased()
        let blocked = [
            "/var/mobile/library/preferences/com.apple.springboard.plist",
            "/var/mobile/library/preferences/systemconfiguration",
            "/var/keybags",
        ]
        return !blocked.contains(where: { lower.hasPrefix($0) })
    }
}

// TempSpaceRegistry.swift — Temporary file lease registry
// Reconstructed from 5013 v3.2.17 binary
//
// 61 symbols found. Tracks Lease values with Retention policy.
// purgeExpired(now:) called at app launch.

import Foundation

enum TempSpaceRegistry {

    struct Lease: Identifiable {
        let id: UUID
        let url: URL
        let createdAt: Date
        let retention: Retention
    }

    enum Retention: Int, Hashable {
        case temporary = 0
        case session = 1
        case persistent = 2
    }

    private static var leases: [Lease] = []
    private static let lock = NSLock()

    static func register(_ url: URL, retention: Retention = .temporary) -> Lease {
        let lease = Lease(id: UUID(), url: url, createdAt: Date(), retention: retention)
        lock.lock()
        leases.append(lease)
        lock.unlock()
        return lease
    }

    static func forget(_ lease: Lease) {
        lock.lock()
        leases.removeAll { $0.id == lease.id }
        lock.unlock()
        try? FileManager.default.removeItem(at: lease.url)
    }

    static func purgeExpired(now: Date) {
        lock.lock()
        let expired = leases.filter { lease in
            guard lease.retention == .temporary else { return false }
            return now.timeIntervalSince(lease.createdAt) > 3600
        }
        leases.removeAll { lease in expired.contains(where: { $0.id == lease.id }) }
        lock.unlock()

        for lease in expired {
            try? FileManager.default.removeItem(at: lease.url)
        }
    }
}

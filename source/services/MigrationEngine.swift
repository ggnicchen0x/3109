import Foundation

final class MigrationEngine {

    struct Plan: Codable {
        let id: UUID
        let sourcePath: String
        let destinationPath: String
        let entries: [Entry]
        var resumeIndex: Int

        struct Entry: Codable {
            let relativePath: String
            let isDirectory: Bool
            let size: Int64
        }
    }

    enum State: Equatable {
        case idle
        case planning
        case running(progress: Double)
        case paused(progress: Double)
        case completed
        case failed(String)
    }

    private(set) var state: State = .idle
    private var currentPlan: Plan?
    private let fileManager = FileManager.default
    private var cancellationToken = CancellationToken()
    private let queue = DispatchQueue(label: "5013.migration", qos: .userInitiated)

    var progress: Double {
        switch state {
        case .running(let p), .paused(let p): return p
        default: return 0
        }
    }

    func buildPlan(source: URL, destination: URL) throws -> Plan {
        state = .planning
        var entries: [Plan.Entry] = []

        let enumerator = fileManager.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        while let itemURL = enumerator?.nextObject() as? URL {
            let rv = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let rel = itemURL.path.replacingOccurrences(of: source.path + "/", with: "")
            entries.append(Plan.Entry(
                relativePath: rel,
                isDirectory: rv.isDirectory ?? false,
                size: Int64(rv.fileSize ?? 0)
            ))
        }

        let plan = Plan(
            id: UUID(),
            sourcePath: source.path,
            destinationPath: destination.path,
            entries: entries,
            resumeIndex: 0
        )
        currentPlan = plan
        state = .idle
        return plan
    }

    func execute(plan: Plan, progressHandler: ((Double) -> Void)? = nil) {
        cancellationToken = CancellationToken()
        var mutablePlan = plan
        currentPlan = mutablePlan
        state = .running(progress: 0)

        queue.async { [weak self] in
            guard let self = self else { return }

            let total = mutablePlan.entries.count
            guard total > 0 else {
                DispatchQueue.main.async { self.state = .completed }
                return
            }

            for i in mutablePlan.resumeIndex..<total {
                if self.cancellationToken.isCancelled {
                    mutablePlan.resumeIndex = i
                    self.currentPlan = mutablePlan
                    DispatchQueue.main.async {
                        let p = Double(i) / Double(total)
                        self.state = .paused(progress: p)
                    }
                    return
                }

                let entry = mutablePlan.entries[i]
                let src = URL(fileURLWithPath: mutablePlan.sourcePath)
                    .appendingPathComponent(entry.relativePath)
                let dst = URL(fileURLWithPath: mutablePlan.destinationPath)
                    .appendingPathComponent(entry.relativePath)

                do {
                    if entry.isDirectory {
                        try self.fileManager.createDirectory(at: dst, withIntermediateDirectories: true)
                    } else {
                        let parent = dst.deletingLastPathComponent()
                        if !self.fileManager.fileExists(atPath: parent.path) {
                            try self.fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
                        }
                        if self.fileManager.fileExists(atPath: dst.path) {
                            try self.fileManager.removeItem(at: dst)
                        }
                        try self.fileManager.copyItem(at: src, to: dst)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.state = .failed(error.localizedDescription)
                    }
                    return
                }

                let p = Double(i + 1) / Double(total)
                DispatchQueue.main.async {
                    self.state = .running(progress: p)
                    progressHandler?(p)
                }
            }

            DispatchQueue.main.async { self.state = .completed }
        }
    }

    func pause() {
        cancellationToken.cancel()
    }

    func resume(progressHandler: ((Double) -> Void)? = nil) {
        guard let plan = currentPlan else { return }
        execute(plan: plan, progressHandler: progressHandler)
    }

    func cancel() {
        cancellationToken.cancel()
        currentPlan = nil
        state = .idle
    }

    func savePlan(_ plan: Plan, to url: URL) throws {
        let data = try JSONEncoder().encode(plan)
        try data.write(to: url, options: .atomic)
    }

    func loadPlan(from url: URL) throws -> Plan {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Plan.self, from: data)
    }
}

final class CancellationToken {
    private var _cancelled = false
    private let lock = NSLock()

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _cancelled
    }

    func cancel() {
        lock.lock()
        _cancelled = true
        lock.unlock()
    }
}

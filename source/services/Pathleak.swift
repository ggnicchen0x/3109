import Foundation

final class Pathleak {

    struct Result {
        let inode: UInt64
        let path: String
    }

    private let workerCount: Int
    private let queue = DispatchQueue(label: "5013.pathleak", qos: .userInitiated, attributes: .concurrent)
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var results: [Result] = []
    private var cancelled = false

    init(workerCount: Int = 4) {
        self.workerCount = max(1, workerCount)
    }

    func scan(root: String, inodeRange: ClosedRange<UInt64>, completion: @escaping ([Result]) -> Void) {
        cancelled = false
        results.removeAll()

        let chunkSize = max(1, (inodeRange.upperBound - inodeRange.lowerBound + 1) / UInt64(workerCount))

        for w in 0..<workerCount {
            let lo = inodeRange.lowerBound + UInt64(w) * chunkSize
            let hi = min(lo + chunkSize - 1, inodeRange.upperBound)
            guard lo <= hi else { continue }

            group.enter()
            queue.async { [weak self] in
                defer { self?.group.leave() }
                self?.scanRange(root: root, lo: lo, hi: hi)
            }
        }

        group.notify(queue: .main) { [weak self] in
            completion(self?.results ?? [])
        }
    }

    func cancel() {
        cancelled = true
    }

    private func scanRange(root: String, lo: UInt64, hi: UInt64) {
        let fm = FileManager.default
        var inode = lo

        while inode <= hi && !cancelled {
            let testPath = root + "/.pathleak_\(inode)"

            // Try to discover path for inode by scanning directory entries
            if let enumerator = fm.enumerator(atPath: root) {
                while let item = enumerator.nextObject() as? String {
                    if cancelled { return }
                    let fullPath = (root as NSString).appendingPathComponent(item)
                    var stat = stat()
                    if lstat(fullPath, &stat) == 0 && stat.st_ino == inode {
                        lock.lock()
                        results.append(Result(inode: inode, path: fullPath))
                        lock.unlock()
                        break
                    }
                }
            }
            inode += 1
        }
    }

    static func enumerateInodes(at path: String) -> [(inode: UInt64, name: String)] {
        var entries: [(inode: UInt64, name: String)] = []
        guard let dir = opendir(path) else { return entries }
        defer { closedir(dir) }

        while let ent = readdir(dir) {
            let name = withUnsafePointer(to: ent.pointee.d_name) { ptr in
                String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
            }
            if name == "." || name == ".." { continue }
            entries.append((inode: ent.pointee.d_ino, name: name))
        }
        return entries
    }

    static func pathForInode(_ inode: UInt64, searchRoot: String) -> String? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: searchRoot) else { return nil }
        while let item = enumerator.nextObject() as? String {
            let fullPath = (searchRoot as NSString).appendingPathComponent(item)
            var sb = stat()
            if lstat(fullPath, &sb) == 0 && sb.st_ino == inode {
                return fullPath
            }
        }
        return nil
    }
}

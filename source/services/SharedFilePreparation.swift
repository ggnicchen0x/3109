import Foundation

enum SharedFilePreparation {

    struct PreparedFile {
        let originalURL: URL
        let stagedURL: URL
        let size: Int64
    }

    static func prepare(url: URL, in stagingDir: URL) throws -> PreparedFile {
        let fm = FileManager.default
        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let staged = stagingDir.appendingPathComponent(url.lastPathComponent)
        if fm.fileExists(atPath: staged.path) {
            try fm.removeItem(at: staged)
        }
        try fm.copyItem(at: url, to: staged)

        let attrs = try fm.attributesOfItem(atPath: staged.path)
        let size = (attrs[.size] as? Int64) ?? 0

        return PreparedFile(originalURL: url, stagedURL: staged, size: size)
    }

    static func prepareBatch(urls: [URL], in stagingDir: URL) throws -> [PreparedFile] {
        try urls.map { try prepare(url: $0, in: stagingDir) }
    }

    static func cleanup(stagingDir: URL) {
        try? FileManager.default.removeItem(at: stagingDir)
    }
}

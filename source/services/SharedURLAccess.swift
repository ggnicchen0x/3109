import Foundation

final class SharedURLAccess {

    static let shared = SharedURLAccess()

    private let lock = NSLock()
    private var activeBookmarks: [URL: Data] = [:]

    private init() {}

    func startAccessing(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if url.startAccessingSecurityScopedResource() {
            if let bookmark = try? url.bookmarkData(options: .minimalBookmark,
                                                      includingResourceValuesForKeys: nil,
                                                      relativeTo: nil) {
                activeBookmarks[url] = bookmark
            }
            return true
        }
        return false
    }

    func stopAccessing(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        url.stopAccessingSecurityScopedResource()
        activeBookmarks.removeValue(forKey: url)
    }

    func stopAll() {
        lock.lock()
        let urls = Array(activeBookmarks.keys)
        lock.unlock()
        for url in urls {
            stopAccessing(url)
        }
    }

    func isAccessing(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeBookmarks[url] != nil
    }

    func resolveBookmark(_ data: Data) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                  options: [],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale { return nil }
        return url
    }
}

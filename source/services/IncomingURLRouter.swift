import Foundation
import Combine

final class IncomingURLRouter: ObservableObject {

    struct Request: Identifiable {
        let id: UUID
        let url: URL
        let receivedAt: Date

        func discardSnapshot() {
            Task {
                // Async cleanup of any staged snapshot for this request
            }
        }
    }

    enum Route {
        case patchImport(URL)
        case repositoryAdd(URL)
        case fileOpen(String)
        case airliftPairing(URL)
        case settings(section: String?)
        case scan(path: String?)
        case wallpaperImport(URL)
        case fontImport(URL)
        case backup(action: String?)
        case unknown(URL)
    }

    static let shared = IncomingURLRouter(inboxRoot: nil, preparesFiles: false)

    @Published var currentRequest: Request?
    @Published var overflowID: UUID?
    @Published private(set) var isProcessing: Bool = false

    private var queue: [Request] = []
    private let lock = NSLock()
    private var consumeTask: Task<Void, Never>?

    var onRoute: ((Route) -> Void)?

    init(inboxRoot: URL?, preparesFiles: Bool) {}

    func enqueue(_ url: URL, at date: Date = Date()) {
        let request = Request(id: UUID(), url: url, receivedAt: date)
        lock.lock()
        queue.append(request)
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.advanceQueue()
        }
    }

    func finish(_ id: UUID) {
        lock.lock()
        queue.removeAll { $0.id == id }
        isProcessing = false
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.advanceQueue()
        }
    }

    func advanceQueue() {
        lock.lock()
        guard !isProcessing, let next = queue.first else {
            lock.unlock()
            currentRequest = queue.first
            return
        }
        isProcessing = true
        currentRequest = next
        lock.unlock()

        consumeTask?.cancel()
        consumeTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.consumeIncomingURL(next)
        }
    }

    @MainActor
    private func consumeIncomingURL(_ request: Request) async {
        let route = resolve(request.url)
        onRoute?(route)
    }

    private func resolve(_ url: URL) -> Route {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        if scheme == "fivethirteen" || scheme == "5013" {
            return resolveCustomScheme(host: host, path: path, url: url)
        }

        if url.isFileURL {
            return resolveFileURL(url)
        }

        if scheme == "http" || scheme == "https" {
            if isRepositoryURL(url) {
                return .repositoryAdd(url)
            }
        }

        return .unknown(url)
    }

    private func resolveCustomScheme(host: String, path: String, url: URL) -> Route {
        switch host {
        case "patch", "import-patch":
            if let fileURL = extractFileURL(from: url) { return .patchImport(fileURL) }
            return .unknown(url)
        case "repo", "repository", "add-repo":
            if let repoURL = extractRepoURL(from: url) { return .repositoryAdd(repoURL) }
            return .unknown(url)
        case "file", "open":
            let filePath = url.queryItems["path"] ?? path
            return .fileOpen(filePath)
        case "airlift", "pairing":
            if let fileURL = extractFileURL(from: url) { return .airliftPairing(fileURL) }
            return .unknown(url)
        case "settings":
            return .settings(section: url.queryItems["section"])
        case "scan":
            return .scan(path: url.queryItems["path"])
        case "wallpaper":
            if let fileURL = extractFileURL(from: url) { return .wallpaperImport(fileURL) }
            return .unknown(url)
        case "font":
            if let fileURL = extractFileURL(from: url) { return .fontImport(fileURL) }
            return .unknown(url)
        case "backup":
            return .backup(action: url.queryItems["action"])
        default:
            return .unknown(url)
        }
    }

    private func resolveFileURL(_ url: URL) -> Route {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "patch", "5013patch": return .patchImport(url)
        case "repo", "5013repo":  return .repositoryAdd(url)
        case "ttf", "otf", "ttc", "woff", "woff2": return .fontImport(url)
        case "png", "jpg", "jpeg", "heic", "webp": return .wallpaperImport(url)
        case "plist", "mobileprovision":           return .airliftPairing(url)
        default: return .fileOpen(url.path)
        }
    }

    private func isRepositoryURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("github.com") || host.contains("gitlab.com") ||
               host.contains("bitbucket.org") || url.pathExtension == "json"
    }

    private func extractFileURL(from url: URL) -> URL? {
        if let path = url.queryItems["file"] ?? url.queryItems["path"] {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func extractRepoURL(from url: URL) -> URL? {
        if let urlString = url.queryItems["url"],
           let repoURL = URL(string: urlString) {
            return repoURL
        }
        return nil
    }
}

private extension URL {
    var queryItems: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return [:] }
        var dict: [String: String] = [:]
        for item in items { dict[item.name] = item.value }
        return dict
    }
}

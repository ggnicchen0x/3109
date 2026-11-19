import Foundation
import UIKit

final class StoreIconFallbackService {

    static let shared = StoreIconFallbackService()

    private var cache: [String: UIImage] = [:]
    private let lock = NSLock()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.urlCache = URLCache(memoryCapacity: 10 * 1024 * 1024,
                                    diskCapacity: 50 * 1024 * 1024)
        session = URLSession(configuration: config)
    }

    func icon(for bundleID: String) -> UIImage? {
        lock.lock()
        let cached = cache[bundleID]
        lock.unlock()
        return cached
    }

    func fetchIcon(for bundleID: String, size: Int = 120) async -> UIImage? {
        if let cached = icon(for: bundleID) { return cached }

        let urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleID)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await session.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artworkURL = first["artworkUrl512"] as? String ?? first["artworkUrl100"] as? String,
                  let imageURL = URL(string: artworkURL) else {
                return nil
            }

            let (imageData, _) = try await session.data(from: imageURL)
            guard let image = UIImage(data: imageData) else { return nil }

            lock.lock()
            cache[bundleID] = image
            lock.unlock()

            return image
        } catch {
            return nil
        }
    }

    func clearCache() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}

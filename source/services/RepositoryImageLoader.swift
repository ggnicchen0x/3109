import Foundation
import UIKit
import Combine

final class RepositoryImageLoader: ObservableObject {

    @Published var image: UIImage?
    @Published var isLoading: Bool = false

    private var task: URLSessionDataTask?
    private static let pipeline = RepositoryImagePipeline.shared

    func load(from url: URL) {
        if let cached = Self.pipeline.cached(url) {
            image = cached
            return
        }

        isLoading = true
        task = Self.pipeline.fetch(url) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                if case .success(let img) = result {
                    self?.image = img
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }
}

final class RepositoryImagePipeline {

    static let shared = RepositoryImagePipeline()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024

        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 5 * 1024 * 1024,
                                    diskCapacity: 30 * 1024 * 1024)
        session = URLSession(configuration: config)
    }

    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func fetch(_ url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) -> URLSessionDataTask {
        let task = session.dataTask(with: url) { [weak self] data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(ImagePipelineError.decodeFailed))
                return
            }
            self?.cache.setObject(image, forKey: url as NSURL, cost: data.count)
            completion(.success(image))
        }
        task.resume()
        return task
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

enum ImagePipelineError: LocalizedError {
    case decodeFailed
    var errorDescription: String? { "Failed to decode image data" }
}

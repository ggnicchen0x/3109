import Foundation
import Combine

final class PackageRepositoryStore: ObservableObject {

    @Published var repositories: [PackageRepository] = []

    private static var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("repositories.json")
    }

    init() {
        load()
    }

    func allRepositories() -> [PackageRepository] {
        repositories.sorted { $0.addedAt > $1.addedAt }
    }

    func add(name: String, url: URL) {
        guard !repositories.contains(where: { $0.url == url }) else { return }
        let repo = PackageRepository(id: UUID(), name: name, url: url, addedAt: Date())
        repositories.append(repo)
        save()
    }

    func remove(_ id: UUID) {
        repositories.removeAll { $0.id == id }
        save()
    }

    func updateName(_ id: UUID, name: String) {
        guard let idx = repositories.firstIndex(where: { $0.id == id }) else { return }
        let old = repositories[idx]
        repositories[idx] = PackageRepository(id: old.id, name: name, url: old.url, addedAt: old.addedAt)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.storeURL),
              let decoded = try? JSONDecoder().decode([PackageRepository].self, from: data) else {
            return
        }
        repositories = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(repositories) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }
}

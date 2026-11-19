import Foundation

final class FileFavoritesStore: ObservableObject {

    @Published private(set) var favorites: [Favorite] = []

    struct Favorite: Codable, Identifiable, Equatable {
        let id: UUID
        let path: String
        let label: String?
        let addedAt: Date

        init(path: String, label: String? = nil) {
            self.id = UUID()
            self.path = path
            self.label = label
            self.addedAt = Date()
        }
    }

    private static var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("file_favorites.json")
    }

    init() {
        load()
    }

    func isFavorite(_ path: String) -> Bool {
        favorites.contains(where: { $0.path == path })
    }

    func add(path: String, label: String? = nil) {
        guard !isFavorite(path) else { return }
        favorites.append(Favorite(path: path, label: label))
        save()
    }

    func remove(path: String) {
        favorites.removeAll(where: { $0.path == path })
        save()
    }

    func toggle(path: String) {
        if isFavorite(path) {
            remove(path: path)
        } else {
            add(path: path)
        }
    }

    func rename(id: UUID, label: String) {
        guard let idx = favorites.firstIndex(where: { $0.id == id }) else { return }
        let old = favorites[idx]
        favorites[idx] = Favorite(path: old.path, label: label)
        save()
    }

    func clear() {
        favorites.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.storeURL),
              let decoded = try? JSONDecoder().decode([Favorite].self, from: data) else {
            return
        }
        favorites = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }
}

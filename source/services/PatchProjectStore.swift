import Foundation
import Combine

final class PatchProjectStore: ObservableObject {

    @Published var projects: [PatchProject] = []

    private static var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("patch_projects.json")
    }

    init() {
        load()
    }

    func allProjects() -> [PatchProject] {
        projects.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func project(id: UUID) -> PatchProject? {
        projects.first(where: { $0.id == id })
    }

    func create(name: String) {
        let project = PatchProject(
            id: UUID(), name: name, entries: [],
            createdAt: Date(), modifiedAt: Date()
        )
        projects.append(project)
        save()
    }

    func update(_ project: PatchProject) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        var updated = project
        updated.modifiedAt = Date()
        projects[idx] = updated
        save()
    }

    func delete(_ id: UUID) {
        projects.removeAll { $0.id == id }
        save()
    }

    func addEntry(to projectID: UUID, entry: PatchEntry) {
        guard let idx = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[idx].entries.append(entry)
        projects[idx].modifiedAt = Date()
        save()
    }

    func removeEntry(from projectID: UUID, entryID: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[idx].entries.removeAll { $0.id == entryID }
        projects[idx].modifiedAt = Date()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.storeURL),
              let decoded = try? JSONDecoder().decode([PatchProject].self, from: data) else {
            return
        }
        projects = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }
}

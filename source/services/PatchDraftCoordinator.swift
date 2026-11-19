import Foundation
import Combine

final class PatchDraftCoordinator: ObservableObject {

    struct SharedDestination {
        let url: URL
        let name: String?
    }

    struct Draft {
        let id: UUID
        let projectID: UUID
        let entries: [PatchEntry]
        let destination: SharedDestination?
    }

    @Published var isPresenting: Bool = false
    @Published var currentDraft: Draft?

    func present(projectID: UUID, entries: [PatchEntry], destination: SharedDestination) async throws {
        let draft = Draft(id: UUID(), projectID: projectID, entries: entries, destination: destination)
        await MainActor.run {
            currentDraft = draft
            isPresenting = true
        }
    }

    func present(_ destination: SharedDestination) async throws {
        await MainActor.run {
            isPresenting = true
        }
    }

    func dismiss() {
        isPresenting = false
        currentDraft = nil
    }

    func apply(draft: Draft, using fileManager: FileManager = .default) throws {
        for entry in draft.entries {
            switch entry.action {
            case .copy:
                guard let source = entry.sourcePath else { continue }
                let sourceURL = URL(fileURLWithPath: source)
                let targetURL = URL(fileURLWithPath: entry.targetPath)
                let parent = targetURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: parent.path) {
                    try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
                }
                if fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.removeItem(at: targetURL)
                }
                try fileManager.copyItem(at: sourceURL, to: targetURL)

            case .delete:
                try fileManager.removeItem(atPath: entry.targetPath)

            case .mkdir:
                try fileManager.createDirectory(atPath: entry.targetPath, withIntermediateDirectories: true)

            case .plistSet:
                guard let key = entry.plistKey, let value = entry.plistValue else { continue }
                let doc = try PlistDocument(url: URL(fileURLWithPath: entry.targetPath))
                doc.setValue(value, forKeyPath: key)
                try doc.write()

            case .plistDelete:
                guard let key = entry.plistKey else { continue }
                let doc = try PlistDocument(url: URL(fileURLWithPath: entry.targetPath))
                doc.setValue(NSNull(), forKeyPath: key)
                try doc.write()

            case .symlink:
                guard let source = entry.sourcePath else { continue }
                try fileManager.createSymbolicLink(atPath: entry.targetPath, withDestinationPath: source)

            case .move:
                guard let source = entry.sourcePath else { continue }
                try fileManager.moveItem(atPath: source, toPath: entry.targetPath)
            }
        }
    }
}

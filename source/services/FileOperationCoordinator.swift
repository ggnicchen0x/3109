import Foundation
import Combine

final class FileOperationCoordinator: ObservableObject {

    @Published var isOperating: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentOperation: String?
    @Published var error: Error?

    private var cancellationToken: CancellationToken?

    func beginOperation(_ name: String) {
        isOperating = true
        currentOperation = name
        progress = 0.0
        error = nil
        cancellationToken = CancellationToken()
    }

    func updateProgress(_ value: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.progress = min(1.0, max(0.0, value))
        }
    }

    func endOperation() {
        isOperating = false
        currentOperation = nil
        progress = 1.0
        cancellationToken = nil
    }

    func failOperation(_ error: Error) {
        self.error = error
        isOperating = false
        currentOperation = nil
        cancellationToken = nil
    }

    func cancel() {
        cancellationToken?.cancel()
        isOperating = false
        currentOperation = nil
    }

    var isCancelled: Bool {
        cancellationToken?.isCancelled ?? false
    }

    func copyFile(from source: URL, to destination: URL) throws {
        beginOperation("Copying \(source.lastPathComponent)")
        defer { endOperation() }

        let fm = FileManager.default
        let parent = destination.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
    }

    func moveFile(from source: URL, to destination: URL) throws {
        beginOperation("Moving \(source.lastPathComponent)")
        defer { endOperation() }

        let fm = FileManager.default
        let parent = destination.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: source, to: destination)
    }

    func deleteFile(at url: URL) throws {
        beginOperation("Deleting \(url.lastPathComponent)")
        defer { endOperation() }
        try FileManager.default.removeItem(at: url)
    }
}

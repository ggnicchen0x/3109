import Foundation
import Combine

final class PatchProgressMailbox: ObservableObject {

    struct Progress {
        let patchID: UUID
        let step: String
        let fraction: Double
        let message: String?
    }

    @Published private(set) var current: Progress?
    @Published private(set) var isActive: Bool = false

    private let lock = NSLock()

    func post(patchID: UUID, step: String, fraction: Double, message: String? = nil) {
        let progress = Progress(patchID: patchID, step: step, fraction: fraction, message: message)
        DispatchQueue.main.async { [weak self] in
            self?.current = progress
            self?.isActive = true
        }
    }

    func complete(patchID: UUID) {
        DispatchQueue.main.async { [weak self] in
            if self?.current?.patchID == patchID {
                self?.current = nil
                self?.isActive = false
            }
        }
    }

    func reset() {
        DispatchQueue.main.async { [weak self] in
            self?.current = nil
            self?.isActive = false
        }
    }
}

import Foundation

final class ScanToken {

    private var _cancelled = false
    private let lock = NSLock()
    let id = UUID()

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _cancelled
    }

    func cancel() {
        lock.lock()
        _cancelled = true
        lock.unlock()
    }

    func throwIfCancelled() throws {
        guard !isCancelled else {
            throw ScanCancellationError()
        }
    }
}

struct ScanCancellationError: LocalizedError {
    var errorDescription: String? { "Scan was cancelled" }
}

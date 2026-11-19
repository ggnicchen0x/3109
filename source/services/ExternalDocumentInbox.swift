import Foundation

final class ExternalDocumentInbox {

    static let shared = ExternalDocumentInbox()

    private let inboxURL: URL
    private let fm = FileManager.default

    private init() {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        inboxURL = docs.appendingPathComponent("Inbox")
        try? fm.createDirectory(at: inboxURL, withIntermediateDirectories: true)
    }

    func pendingFiles() -> [URL] {
        (try? fm.contentsOfDirectory(at: inboxURL,
                                      includingPropertiesForKeys: [.creationDateKey],
                                      options: [.skipsHiddenFiles])) ?? []
    }

    func accept(_ url: URL, moveTo destination: URL) throws {
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: url, to: destination)
    }

    func discard(_ url: URL) throws {
        try fm.removeItem(at: url)
    }

    func discardAll() {
        for file in pendingFiles() {
            try? fm.removeItem(at: file)
        }
    }

    func hasFiles() -> Bool {
        !pendingFiles().isEmpty
    }
}

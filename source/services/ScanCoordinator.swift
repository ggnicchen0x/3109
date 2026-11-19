import Foundation
import Combine

final class ScanCoordinator: ObservableObject {

    @Published var isScanning: Bool = false
    @Published var progress: Double = 0.0
    @Published var scannedCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var currentFile: String?
    @Published var results: [ScanResult] = []

    private var scanToken: ScanToken?
    private let queue = DispatchQueue(label: "5013.scan", qos: .userInitiated)

    struct ScanResult: Identifiable {
        let id = UUID()
        let path: String
        let issue: String
        let severity: Severity
    }

    enum Severity {
        case info, warning, error
    }

    func startScan(paths: [String] = ["/"]) {
        guard !isScanning else { return }
        isScanning = true
        progress = 0.0
        scannedCount = 0
        totalCount = 0
        results = []
        scanToken = ScanToken()

        queue.async { [weak self] in
            guard let self = self else { return }
            self.performScan(paths: paths)
        }
    }

    func cancelScan() {
        scanToken?.cancel()
        DispatchQueue.main.async { [weak self] in
            self?.isScanning = false
        }
    }

    private func performScan(paths: [String]) {
        let fm = FileManager.default

        // Count total files first
        var allFiles: [String] = []
        for root in paths {
            if let enumerator = fm.enumerator(atPath: root) {
                while let item = enumerator.nextObject() as? String {
                    if scanToken?.isCancelled == true { break }
                    let full = (root as NSString).appendingPathComponent(item)
                    allFiles.append(full)
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.totalCount = allFiles.count
        }

        for (index, path) in allFiles.enumerated() {
            if scanToken?.isCancelled == true { break }

            let url = URL(fileURLWithPath: path)
            let ext = url.pathExtension.lowercased()

            // Check SQLite databases
            if ext == "db" || ext == "sqlite" || ext == "sqlite3" {
                if SQLiteAPI.isDatabase(at: url) {
                    let integrity = SQLiteIntegrityService.check(databaseURL: url)
                    if !integrity.isOK {
                        let result = ScanResult(path: path, issue: "Database integrity issue", severity: .warning)
                        DispatchQueue.main.async { [weak self] in
                            self?.results.append(result)
                        }
                    }
                }
            }

            // Check plist files
            if ext == "plist" {
                if let data = try? Data(contentsOf: url),
                   (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) == nil {
                    let result = ScanResult(path: path, issue: "Invalid plist", severity: .error)
                    DispatchQueue.main.async { [weak self] in
                        self?.results.append(result)
                    }
                }
            }

            // Check safety policy
            if CleanerSafetyPolicy.isSystemProtected(path) {
                let result = ScanResult(path: path, issue: "System protected", severity: .info)
                DispatchQueue.main.async { [weak self] in
                    self?.results.append(result)
                }
            }

            let p = Double(index + 1) / max(1.0, Double(allFiles.count))
            DispatchQueue.main.async { [weak self] in
                self?.scannedCount = index + 1
                self?.progress = p
                self?.currentFile = url.lastPathComponent
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.isScanning = false
            self?.currentFile = nil
        }
    }
}

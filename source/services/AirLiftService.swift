// AirLiftService.swift — AirLift sandbox escape backend
// Reconstructed from 5013 v3.2.17 binary (60 functions)
//
// Singleton service that manages a pairing file for AirLift-based
// sandbox access. Operations dispatched to a private serial queue
// labeled "5013.airlift". Calls into AirLiftPolicy for file I/O.

import Foundation
import Combine

class AirLiftService: ObservableObject {

    static let shared: AirLiftService = {
        let service = AirLiftService()
        return service
    }()

    @Published var isBusy: Bool = false
    @Published var hasPairing: Bool = false
    @Published var statusKey: String = "airlift.status.none"
    @Published var errorMessage: String?

    private static var pairingURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("airlift_pairing.dat")
    }

    private let queue = DispatchQueue(label: "5013.airlift", qos: .userInitiated)

    private init() {
        let exists = FileManager.default.fileExists(atPath: Self.pairingURL.path)
        hasPairing = exists
    }

    // MARK: - Import pairing

    func importPairing(at url: URL) {
        perform { [weak self] in
            guard let self = self else { return "" }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            try data.write(to: Self.pairingURL, options: .atomic)
            DispatchQueue.main.async {
                self.hasPairing = true
                self.statusKey = "airlift.status.paired"
                self.errorMessage = nil
            }
            return "import_ok"
        }
    }

    // MARK: - Remove pairing

    func removePairing() {
        perform { [weak self] in
            try? FileManager.default.removeItem(at: Self.pairingURL)
            DispatchQueue.main.async {
                self?.hasPairing = false
                self?.statusKey = "airlift.status.none"
                self?.errorMessage = nil
            }
            return "remove_ok"
        }
    }

    // MARK: - Probe

    func probe() {
        perform { [weak self] in
            try Self.preflight()
            let data = try Data(contentsOf: Self.pairingURL, options: .mappedIfSafe)
            let _ = try AirLiftPolicy.pairingFormat(data)
            DispatchQueue.main.async {
                self?.statusKey = "airlift.status.ready"
                self?.errorMessage = nil
            }
            return "probe_ok"
        }
    }

    // MARK: - Write directory

    func writeDirectory(from url: URL, to path: String) {
        perform { [weak self] in
            try Self.preflight()
            try Self.stageFiles(from: url, to: Self.pairingURL)
            DispatchQueue.main.async {
                self?.statusKey = "airlift.status.written"
            }
            return "write_ok"
        }
    }

    // MARK: - Preflight

    private static func preflight() throws {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        // AirLift only on iOS 18.7.11+
        guard v.majorVersion == 18 && v.minorVersion == 7 && v.patchVersion >= 11 else {
            throw AirLiftError.unsupportedOS
        }
        guard FileManager.default.fileExists(atPath: pairingURL.path) else {
            throw AirLiftError.noPairing
        }
        let data = try AirLiftPolicy.readBounded(at: pairingURL, maximumBytes: 0x100000)
        let _ = try AirLiftPolicy.pairingFormat(data)
    }

    // MARK: - Stage files

    private static func stageFiles(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for item in contents {
            let target = destination.deletingLastPathComponent()
                .appendingPathComponent(item.lastPathComponent)
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            try fm.copyItem(at: item, to: target)
        }
    }

    // MARK: - Transport error

    private static func transportError(_ rawPointer: UnsafeMutablePointer<Int8>?, fallback: AirLiftError) -> Error {
        if let ptr = rawPointer {
            return AirLiftError.transport(String(cString: ptr))
        }
        return fallback
    }

    // MARK: - Perform (private serial dispatch)

    private func perform(_ work: @escaping () throws -> String) {
        guard !isBusy else { return }

        DispatchQueue.main.async { [weak self] in
            self?.isBusy = true
            self?.errorMessage = nil
            self?.statusKey = "airlift.status.working"
        }

        queue.async { [weak self] in
            do {
                let _ = try work()
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.statusKey = "airlift.status.error"
                }
            }
            DispatchQueue.main.async {
                self?.isBusy = false
            }
        }
    }
}

// MARK: - AirLiftError

enum AirLiftError: LocalizedError {
    case unsupportedOS
    case noPairing
    case invalidPairing
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:   return "Unsupported OS version for AirLift"
        case .noPairing:       return "No AirLift pairing file found"
        case .invalidPairing:  return "Invalid pairing file format"
        case .transport(let m): return "Transport error: \(m)"
        }
    }
}

// MARK: - AirLiftPolicy

enum AirLiftPolicy {
    static func readBounded(at url: URL, maximumBytes: Int) throws -> Data {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= maximumBytes else {
            throw AirLiftError.invalidPairing
        }
        return data
    }

    static func pairingFormat(_ data: Data) throws -> Any {
        guard data.count > 0 else {
            throw AirLiftError.invalidPairing
        }
        // Pairing format validation
        return data
    }
}

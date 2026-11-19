import Foundation

final class GestaltBaselineStore {

    struct Baseline: Codable {
        let capturedAt: Date
        let osVersion: String
        let osBuild: String
        let entries: [String: PlistScalar]
    }

    private var currentBaseline: Baseline?
    private let fileManager = FileManager.default

    private static var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("gestalt_baseline.json")
    }

    init() {
        currentBaseline = Self.load()
    }

    var baseline: Baseline? { currentBaseline }

    func capture(entries: [String: PlistScalar]) {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"

        var size: Int = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &buf, &size, nil, 0)
        let osBuild = String(cString: buf)

        let baseline = Baseline(
            capturedAt: Date(),
            osVersion: osVersion,
            osBuild: osBuild,
            entries: entries
        )
        currentBaseline = baseline
        save(baseline)
    }

    func compare(current: [String: PlistScalar]) -> [Difference] {
        guard let baseline = currentBaseline else { return [] }
        var diffs: [Difference] = []

        let allKeys = Set(baseline.entries.keys).union(current.keys)
        for key in allKeys.sorted() {
            let old = baseline.entries[key]
            let new = current[key]
            if old != new {
                diffs.append(Difference(key: key, baseline: old, current: new))
            }
        }
        return diffs
    }

    func clear() {
        currentBaseline = nil
        try? fileManager.removeItem(at: Self.storeURL)
    }

    struct Difference {
        let key: String
        let baseline: PlistScalar?
        let current: PlistScalar?
    }

    private func save(_ baseline: Baseline) {
        guard let data = try? JSONEncoder().encode(baseline) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }

    private static func load() -> Baseline? {
        guard let data = try? Data(contentsOf: storeURL) else { return nil }
        return try? JSONDecoder().decode(Baseline.self, from: data)
    }
}

enum PlistScalar: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case data(Data)
    case date(Date)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode(Data.self) {
            self = .data(v)
        } else if let v = try? container.decode(Date.self) {
            self = .date(v)
        } else {
            throw DecodingError.typeMismatch(PlistScalar.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown scalar"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        case .data(let v):   try container.encode(v)
        case .date(let v):   try container.encode(v)
        }
    }

    var displayString: String {
        switch self {
        case .string(let v): return v
        case .int(let v):    return "\(v)"
        case .double(let v): return "\(v)"
        case .bool(let v):   return v ? "true" : "false"
        case .data(let v):   return "\(v.count) bytes"
        case .date(let v):   return "\(v)"
        }
    }
}

import Foundation

final class PlistDocument {

    enum Format {
        case xml
        case binary
    }

    let url: URL
    private(set) var root: Any?
    private(set) var format: Format

    init(url: URL) throws {
        self.url = url
        self.format = .xml

        let data = try Data(contentsOf: url)
        var plistFormat: PropertyListSerialization.PropertyListFormat = .xml
        root = try PropertyListSerialization.propertyList(from: data, options: [], format: &plistFormat)

        switch plistFormat {
        case .binary:  format = .binary
        default:       format = .xml
        }
    }

    init(data: Data) throws {
        self.url = URL(fileURLWithPath: "/dev/null")
        self.format = .xml

        var plistFormat: PropertyListSerialization.PropertyListFormat = .xml
        root = try PropertyListSerialization.propertyList(from: data, options: [], format: &plistFormat)

        switch plistFormat {
        case .binary:  format = .binary
        default:       format = .xml
        }
    }

    func value(forKeyPath keyPath: String) -> Any? {
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: Any? = root
        for key in keys {
            if let dict = current as? [String: Any] {
                current = dict[key]
            } else if let arr = current as? [Any], let idx = Int(key), idx < arr.count {
                current = arr[idx]
            } else {
                return nil
            }
        }
        return current
    }

    func setValue(_ value: Any, forKeyPath keyPath: String) {
        let keys = keyPath.split(separator: ".").map(String.init)
        guard !keys.isEmpty else { return }

        if keys.count == 1 {
            if var dict = root as? [String: Any] {
                dict[keys[0]] = value
                root = dict
            }
            return
        }

        func setIn(_ container: inout Any, keys: ArraySlice<String>, value: Any) {
            guard let key = keys.first else { return }
            if keys.count == 1 {
                if var dict = container as? [String: Any] {
                    dict[key] = value
                    container = dict
                }
            } else {
                if var dict = container as? [String: Any] {
                    var child: Any = dict[key] ?? [String: Any]()
                    setIn(&child, keys: keys.dropFirst(), value: value)
                    dict[key] = child
                    container = dict
                }
            }
        }

        var r: Any = root ?? [String: Any]()
        setIn(&r, keys: keys[...], value: value)
        root = r
    }

    func serialize(format: Format? = nil) throws -> Data {
        guard let root = root else {
            throw PlistDocumentError.noRoot
        }
        let fmt: PropertyListSerialization.PropertyListFormat = (format ?? self.format) == .binary
            ? .binary : .xml
        return try PropertyListSerialization.data(fromPropertyList: root, format: fmt, options: 0)
    }

    func write(to url: URL? = nil, format: Format? = nil) throws {
        let data = try serialize(format: format)
        try data.write(to: url ?? self.url, options: .atomic)
    }

    var keys: [String] {
        (root as? [String: Any])?.keys.sorted() ?? []
    }
}

enum PlistDocumentError: LocalizedError {
    case noRoot

    var errorDescription: String? {
        "Plist has no root object"
    }
}

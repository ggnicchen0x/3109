import Foundation
import SQLite3

final class SQLiteReader {

    private var db: OpaquePointer?
    let url: URL

    init(url: URL) throws {
        self.url = url
        let rc = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        guard rc == SQLITE_OK else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(db)
            db = nil
            throw SQLiteError.open(rc, msg)
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func tableNames() throws -> [String] {
        try query("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
            .compactMap { $0["name"] as? String }
    }

    func columnInfo(table: String) throws -> [[String: Any]] {
        try query("PRAGMA table_info(\(Self.quote(table)))")
    }

    func rowCount(table: String) throws -> Int {
        let rows = try query("SELECT COUNT(*) AS c FROM \(Self.quote(table))")
        return (rows.first?["c"] as? Int) ?? 0
    }

    func query(_ sql: String, limit: Int = 500) throws -> [[String: Any]] {
        guard let db = db else { throw SQLiteError.closed }

        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.prepare(rc, msg)
        }
        defer { sqlite3_finalize(stmt) }

        var results: [[String: Any]] = []
        let colCount = sqlite3_column_count(stmt)

        while sqlite3_step(stmt) == SQLITE_ROW && results.count < limit {
            var row: [String: Any] = [:]
            for i in 0..<colCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER:
                    row[name] = Int(sqlite3_column_int64(stmt, i))
                case SQLITE_FLOAT:
                    row[name] = sqlite3_column_double(stmt, i)
                case SQLITE_TEXT:
                    row[name] = String(cString: sqlite3_column_text(stmt, i))
                case SQLITE_BLOB:
                    let len = sqlite3_column_bytes(stmt, i)
                    if let ptr = sqlite3_column_blob(stmt, i) {
                        row[name] = Data(bytes: ptr, count: Int(len))
                    } else {
                        row[name] = Data()
                    }
                default:
                    row[name] = NSNull()
                }
            }
            results.append(row)
        }
        return results
    }

    func integrityCheck() throws -> String {
        let rows = try query("PRAGMA integrity_check", limit: 1)
        return (rows.first?["integrity_check"] as? String) ?? "unknown"
    }

    private static func quote(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

enum SQLiteError: LocalizedError {
    case open(Int32, String)
    case prepare(Int32, String)
    case closed

    var errorDescription: String? {
        switch self {
        case .open(let rc, let msg):    return "SQLite open failed (\(rc)): \(msg)"
        case .prepare(let rc, let msg): return "SQLite prepare failed (\(rc)): \(msg)"
        case .closed:                   return "Database is closed"
        }
    }
}

enum SQLiteAPI {
    static func isDatabase(at url: URL) -> Bool {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return false }
        defer { fh.closeFile() }
        let header = fh.readData(ofLength: 16)
        return header.starts(with: "SQLite format 3".utf8)
    }
}

import Foundation
import LyricsCore
import SQLite3

/// SQLite3 析构约定（Swift 不导出 `SQLITE_TRANSIENT` 宏）。
private let sqliteTransient = unsafeBitCast(
    OpaquePointer(bitPattern: -1),
    to: sqlite3_destructor_type.self
)

/// 缓存条目。
public struct CacheEntry {
    /// 缓存 key。
    public let key: String
    /// 命中源（`SourceID.identifier`）。
    public let source: String
    /// 原文缓存。
    public let raw: String?
    /// 反序列化歌词。
    public let lyrics: LyricsData
    /// 质量档。
    public let quality: LyricsQuality
    /// 创建时刻（秒）。
    public let createdAt: Double
}

/// 歌词缓存（S2 §4；S7 D25 #1：六列 schema 定案 + 迁移机制自首版就位）。
///
/// 表：`lyrics_cache(key, source, raw, parsed_json, quality, created_at)`；
/// schema 版本经 `PRAGMA user_version` 管理，顺序迁移（``migrations``）。
public final class LyricsCache: @unchecked Sendable {
    /// 当前 schema 版本。
    public static var schemaVersion: Int {
        migrations.keys.max() ?? 0
    }

    /// 顺序迁移脚本（版本号 → SQL）。
    private static let migrations: [Int: [String]] = [
        1: [
            """
            CREATE TABLE IF NOT EXISTS lyrics_cache (
                key TEXT PRIMARY KEY,
                source TEXT NOT NULL,
                raw TEXT,
                parsed_json TEXT,
                quality INTEGER NOT NULL,
                created_at REAL NOT NULL
            )
            """,
        ],
    ]

    private let db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.lyricifymac.lyricscache")

    /// 打开缓存并迁移。
    /// - Parameter path: SQLite 路径（测试可传临时文件）。
    public init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open(path, &handle) == SQLITE_OK, let handle else {
            throw LyricsSourceError.transport("sqlite open failed")
        }
        db = handle
        try queue.sync { try migrate() }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    /// 写入/覆盖。
    public func save(
        track: TrackRef,
        source: SourceID,
        raw: String?,
        lyrics: LyricsData,
        quality: LyricsQuality
    ) {
        let key = CacheKey.make(track)
        let parsed = (try? JSONEncoder().encode(lyrics)).flatMap { String(data: $0, encoding: .utf8) }
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO lyrics_cache
            (key, source, raw, parsed_json, quality, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, key, -1, sqliteTransient)
            sqlite3_bind_text(statement, 2, source.identifier, -1, sqliteTransient)
            if let raw {
                sqlite3_bind_text(statement, 3, raw, -1, sqliteTransient)
            } else {
                sqlite3_bind_null(statement, 3)
            }
            if let parsed {
                sqlite3_bind_text(statement, 4, parsed, -1, sqliteTransient)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            sqlite3_bind_int(statement, 5, Int32(quality.rawValue))
            sqlite3_bind_double(statement, 6, Date().timeIntervalSince1970)
            sqlite3_step(statement)
        }
    }

    /// 命中查询。
    /// - Parameter track: 曲目。
    /// - Returns: 缓存条目；未命中时为 `nil`。
    public func hit(track: TrackRef) -> CacheEntry? {
        hit(key: CacheKey.make(track))
    }

    /// 按 key 查询。
    public func hit(key: String) -> CacheEntry? {
        queue.sync {
            let sql = "SELECT key, source, raw, parsed_json, quality, created_at FROM lyrics_cache WHERE key = ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, key, -1, sqliteTransient)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

            let storedKey = String(cString: sqlite3_column_text(statement, 0))
            let source = String(cString: sqlite3_column_text(statement, 1))
            let raw = sqlite3_column_type(statement, 2) == SQLITE_NULL
                ? nil
                : String(cString: sqlite3_column_text(statement, 2))
            let parsedJSON = sqlite3_column_type(statement, 3) == SQLITE_NULL
                ? nil
                : String(cString: sqlite3_column_text(statement, 3))
            let quality = LyricsQuality(rawValue: Int(sqlite3_column_int(statement, 4))) ?? .unknown
            let createdAt = sqlite3_column_double(statement, 5)

            guard let parsedJSON,
                  let lyrics = try? JSONDecoder().decode(
                      LyricsData.self,
                      from: Data(parsedJSON.utf8)
                  )
            else {
                return nil
            }
            return CacheEntry(
                key: storedKey,
                source: source,
                raw: raw,
                lyrics: lyrics,
                quality: quality,
                createdAt: createdAt
            )
        }
    }

    /// 删除单条。
    public func purge(key: String) {
        queue.sync {
            let sql = "DELETE FROM lyrics_cache WHERE key = ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, key, -1, sqliteTransient)
            sqlite3_step(statement)
        }
    }

    /// 清空。
    public func purgeAll() {
        queue.sync {
            _ = sqlite3_exec(db, "DELETE FROM lyrics_cache", nil, nil, nil)
        }
    }

    // MARK: - 迁移（D25 #1）

    private func migrate() throws {
        var version: Int32 = 0
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK,
           sqlite3_step(statement) == SQLITE_ROW
        {
            version = sqlite3_column_int(statement, 0)
        }
        sqlite3_finalize(statement)

        let targets = Self.migrations.keys.sorted()
        for target in targets where target > Int(version) {
            for sql in Self.migrations[target] ?? [] {
                guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                    throw LyricsSourceError.transport("sqlite migration \(target) failed")
                }
            }
            guard sqlite3_exec(db, "PRAGMA user_version = \(target)", nil, nil, nil) == SQLITE_OK else {
                throw LyricsSourceError.transport("sqlite version bump failed")
            }
        }
    }
}

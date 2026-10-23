import LyricsCore
import XCTest
@testable import Sources

/// 缓存层测试（S2 §4；S7 D25 #1 schema/迁移）。
final class CacheTests: XCTestCase {
    private func makeCache() throws -> (LyricsCache, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-\(UUID().uuidString).sqlite")
        return try (LyricsCache(path: url.path), url)
    }

    private func makeTrack() -> TrackRef {
        TrackRef(title: "测试曲名", artists: ["合成歌手甲"], isrc: "TESTISRC2024")
    }

    /// schema 版本基线 + 幂等迁移（D25 #1）。
    func testSchemaMigrationBaseline() throws {
        let (cache, url) = try makeCache()
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(LyricsCache.schemaVersion, 1)
        _ = cache
        // 重开幂等。
        let reopened = try LyricsCache(path: url.path)
        XCTAssertEqual(LyricsCache.schemaVersion, 1)
        _ = reopened
    }

    /// 写入/命中往返（parsed_json 反序列化）。
    func testSaveHitRoundTrip() throws {
        let (cache, url) = try makeCache()
        defer { try? FileManager.default.removeItem(at: url) }
        let track = makeTrack()
        let lyrics = LyricsData(
            lines: [LyricsLine(startMs: 0, endMs: 1000, text: "合成行")],
            syncLevel: .lineSynced,
            source: .lrc
        )
        cache.save(track: track, source: .lrclib, raw: "[00:00.000]合成行", lyrics: lyrics, quality: .lineSynced)

        let entry = try XCTUnwrap(cache.hit(track: track))
        XCTAssertEqual(entry.source, "lrclib")
        XCTAssertEqual(entry.raw, "[00:00.000]合成行")
        XCTAssertEqual(entry.quality, .lineSynced)
        XCTAssertEqual(entry.lyrics.lines.first?.text, "合成行")
    }

    /// key 规则（S2 §4：isrc ?? spotifyUri ?? 归一三元组）。
    func testKeyRule() {
        XCTAssertEqual(
            CacheKey.make(TrackRef(title: "T", artists: ["A"], isrc: "X1", spotifyUri: "u")),
            "isrc:X1"
        )
        XCTAssertEqual(
            CacheKey.make(TrackRef(title: "T", artists: ["A"], spotifyUri: "u")),
            "uri:u"
        )
        let normalized = CacheKey.make(TrackRef(title: "周杰倫", artists: ["A"], durationMs: 100))
        let simplified = CacheKey.make(TrackRef(title: "周杰伦", artists: ["A"], durationMs: 100))
        XCTAssertEqual(normalized, simplified, "繁简归一后 key 稳定")
    }

    /// 覆盖与清除。
    func testOverwriteAndPurge() throws {
        let (cache, url) = try makeCache()
        defer { try? FileManager.default.removeItem(at: url) }
        let track = makeTrack()
        let first = LyricsData(lines: [LyricsLine(text: "一")], source: .lrc)
        let second = LyricsData(lines: [LyricsLine(text: "二")], source: .lrc)
        cache.save(track: track, source: .lrclib, raw: nil, lyrics: first, quality: .lineSynced)
        cache.save(track: track, source: .lrclib, raw: nil, lyrics: second, quality: .syllableSynced)
        XCTAssertEqual(cache.hit(track: track)?.quality, .syllableSynced)
        XCTAssertEqual(cache.hit(track: track)?.lyrics.lines.first?.text, "二")

        cache.purge(key: CacheKey.make(track))
        XCTAssertNil(cache.hit(track: track))
    }
}

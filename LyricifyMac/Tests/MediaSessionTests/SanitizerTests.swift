import LyricsCore
import XCTest
@testable import MediaSession

/// 元数据清洗与封面缓存测试（S3 §6；S7 D29 #2）。
final class SanitizerTests: XCTestCase {
    /// 清洗：去 `(feat. …)`/`【…】`、全角空白归一（D29 #2）。
    func testSanitizedText() {
        XCTAssertEqual(
            MetadataSanitizer.sanitized(text: "测试曲名 (feat. 合成客座)【测试版】"),
            "测试曲名"
        )
        XCTAssertEqual(
            MetadataSanitizer.sanitized(text: "测试\u{3000}曲名"),
            "测试 曲名"
        )
        XCTAssertEqual(
            MetadataSanitizer.sanitized(text: "  首尾空白  "),
            "首尾空白"
        )
    }

    /// 艺术家拆分（S3 §6：`,`/`、`/`&`/` x `）。
    func testSplitArtists() {
        XCTAssertEqual(
            MetadataSanitizer.splitArtists("艺人甲,艺人乙、艺人丙 & 艺人丁 x 艺人戊"),
            ["艺人甲", "艺人乙", "艺人丙", "艺人丁", "艺人戊"]
        )
    }

    /// D38：拆分器防扩张——`/` 不拆（反例 AC/DC、Dave/Tems）。
    func testSlashNotSplitter() {
        XCTAssertEqual(
            MetadataSanitizer.splitArtists("Dave/Tems"),
            ["Dave/Tems"],
            "D38：`/` 不拆（复合艺人由 CompareArtist 规则 6/7 兜住）"
        )
        XCTAssertEqual(MetadataSanitizer.splitArtists("AC/DC"), ["AC/DC"])
    }

    /// 归一 TrackRef（缺失字段降级匹配）。
    func testNormalizedTrackRef() {
        let track = MetadataSanitizer.trackRef(
            title: "曲名 (feat. X)",
            artists: ["A,B"],
            album: "专辑【限定】",
            durationMs: nil,
            bundleID: "com.example"
        )
        XCTAssertEqual(track.title, "曲名")
        XCTAssertEqual(track.artists, ["A", "B"])
        XCTAssertEqual(track.album, "专辑")
        XCTAssertNil(track.durationMs, "缺失字段保留 nil 供降级匹配")
    }

    /// D29 #2：LRU 默认容量 200、淘汰最旧、命中刷新。
    func testArtworkCacheLRU() {
        let cache = ArtworkCache(capacity: 3)
        let tracks = (0 ..< 4).map { TrackRef(title: "曲\($0)", artists: ["A"]) }
        for track in tracks {
            cache.store(Data("img".utf8), for: track)
        }
        XCTAssertEqual(cache.count, 3, "容量淘汰")
        XCTAssertNil(cache.imageData(for: tracks[0]), "最旧被淘汰")

        // 命中刷新 LRU 位。
        _ = cache.imageData(for: tracks[1])
        let newcomer = TrackRef(title: "曲9", artists: ["A"])
        cache.store(Data("img".utf8), for: newcomer)
        XCTAssertNil(cache.imageData(for: tracks[2]), "刷新后曲2 成为最旧被淘汰")
        XCTAssertNotNil(cache.imageData(for: tracks[1]))
        XCTAssertNotNil(cache.imageData(for: newcomer))
    }

    /// D29 #2：默认容量 200。
    func testDefaultCapacity() {
        XCTAssertEqual(ArtworkCache.defaultCapacity, 200)
    }
}

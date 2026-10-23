import LyricsCore
import XCTest
@testable import Sources

/// LocalFiles 适配器测试（S2 §1.1、D6、D26 #3）。
final class LocalFilesTests: XCTestCase {
    /// D26 #3：文件名三模式（`Artist - Title` / `Title - Artist` / `Title`）。
    func testFilenamePatterns() {
        let candidates = FilenameMatcher.candidates(fromFilename: "合成歌手甲 - 测试曲名.lrc")
        XCTAssertEqual(candidates.count, 3)
        XCTAssertEqual(candidates[0].title, "测试曲名")
        XCTAssertEqual(candidates[0].artists, ["合成歌手甲"])
        XCTAssertEqual(candidates[1].title, "合成歌手甲")
        XCTAssertEqual(candidates[1].artists, ["测试曲名"])
        XCTAssertEqual(candidates[2].title, "合成歌手甲 - 测试曲名")
    }

    /// D26 #3：`(Live)` 类质量标记不删除仅弱化匹配。
    func testQualityMarkersPreserved() {
        let candidates = FilenameMatcher.candidates(fromFilename: "测试曲名 (Live).lrc")
        XCTAssertEqual(candidates.last?.title, "测试曲名 (Live)")
    }

    /// D26 #3：CompareHelper + minMatch 接受规则。
    func testMatchAgainstTrack() {
        let track = TrackRef(title: "测试曲名", artists: ["合成歌手甲"])
        let accepted = FilenameMatcher.candidates(fromFilename: "合成歌手甲 - 测试曲名.lrc")
            .contains { FilenameMatcher.isAccepted(candidate: $0, track: track, minMatch: .medium) }
        XCTAssertTrue(accepted)

        let rejected = FilenameMatcher.candidates(fromFilename: "无关文件.lrc")
            .contains { FilenameMatcher.isAccepted(candidate: $0, track: track, minMatch: .medium) }
        XCTAssertFalse(rejected)
    }

    /// D6：翻译副文件配对 → attachTranslation 集成。
    func testTranslationPairingIntegration() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("localfiles-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let main = "[00:01.00]主行合成文本\n"
        let secondary = "[00:01.10]合成译文\n"
        try main.write(to: directory.appendingPathComponent("测试曲.lrc"), atomically: true, encoding: .utf8)
        try secondary.write(
            to: directory.appendingPathComponent("测试曲.tr.lrc"),
            atomically: true,
            encoding: .utf8
        )

        let adapter = LocalFilesAdapter(directories: [directory], minMatch: .low)
        let candidates = try await adapter.search(TrackRef(title: "测试曲", artists: ["合成歌手甲"]))
        XCTAssertEqual(candidates.count, 1)

        let data = try await adapter.fetch(candidates[0])
        XCTAssertEqual(data.lines.count, 1)
        XCTAssertEqual(data.lines[0].text, "主行合成文本")
        XCTAssertEqual(data.lines[0].translation, "合成译文", "±1500ms 就近合并")
    }
}

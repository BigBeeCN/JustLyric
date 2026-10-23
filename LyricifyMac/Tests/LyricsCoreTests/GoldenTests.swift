import XCTest
@testable import LyricsCore

/// golden 语料测试（S1 §6；S6 §2.1-1；S7 D8 规范）。
///
/// 生成：`REGEN_GOLDEN=1 swift test --filter GoldenTests`（生成后人工核对锁定）。
final class GoldenTests: XCTestCase {
    /// 夹具 → golden 文件名（基名 + `.golden.json`）。
    private let goldenMap = [
        "lrc_basic.lrc": "lrc_basic.golden.json",
        "krc_word.krc": "krc_word.golden.json",
        "qrc_word.qrc": "qrc_word.golden.json",
        "yrc_word.yrc": "yrc_word.golden.json",
        "ttml_basic.ttml": "ttml_basic.golden.json",
        "musixmatch_richsync.json": "musixmatch_richsync.golden.json",
        "spotify_colorlyrics.json": "spotify_colorlyrics.golden.json",
        "lyricify_syllable.txt": "lyricify_syllable.golden.json",
        "lyricify_lines.txt": "lyricify_lines.golden.json",
        "instrumental.txt": "instrumental.golden.json",
    ]

    /// golden 序列化（S7 D8：camelCase、sortedKeys+prettyPrinted、nil 省略）。
    private func goldenJSON(_ name: String) throws -> String {
        let data = try parse(FixtureLoader.load(name))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let json = try encoder.encode(data)
        let text = try XCTUnwrap(String(data: json, encoding: .utf8))
        XCTAssertFalse(text.contains("null"), "\(name): nil 字段必须省略")
        return text
    }

    /// 每夹具 golden 相等（S6 §2.1-1）。
    func testGoldenFilesMatch() throws {
        let regen = ProcessInfo.processInfo.environment["REGEN_GOLDEN"] == "1"
        let directory = FixtureLoader.directoryURL()

        for (fixture, goldenName) in goldenMap {
            let text = try goldenJSON(fixture)
            let url = directory.appendingPathComponent(goldenName)
            if regen {
                try text.write(to: url, atomically: true, encoding: .utf8)
                continue
            }
            let expected = try String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(
                expected, text,
                "golden 不一致：\(goldenName)（如为合法变更请 REGEN_GOLDEN=1 重生成并人工核对）"
            )
        }
    }
}

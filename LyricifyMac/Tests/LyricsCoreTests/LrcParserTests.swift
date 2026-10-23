import XCTest
@testable import LyricsCore

/// LRC 解析测试（S1 §2.1；S6 §2.1-1/-2/-3；D9 宽容、D6 行后缀默认关）。
final class LrcParserTests: XCTestCase {
    /// 夹具解析：属性、多时间戳展开（S6 §2.1-3）。
    func testBasicFixture() throws {
        let data = try LrcParser.parse(FixtureLoader.load("lrc_basic.lrc"))
        XCTAssertEqual(data.source, .lrc)
        XCTAssertEqual(data.offsetMs, 100)
        XCTAssertEqual(data.writer, "合成制作者丁")
        XCTAssertEqual(data.trackMeta?.title, "合成曲名丙")
        XCTAssertEqual(data.trackMeta?.artists, ["合成歌手甲"])
        XCTAssertEqual(data.trackMeta?.album, "合成专辑乙")
        XCTAssertEqual(data.trackMeta?.durationMs, 30000)
        XCTAssertEqual(data.syncLevel, .lineSynced)
        XCTAssertEqual(data.lines.count, 4, "多时间戳行展开为多行")
        XCTAssertEqual(data.lines[0].startMs, 5000)
        XCTAssertEqual(data.lines[0].text, "第一行合成歌词")
        XCTAssertEqual(data.lines[1].startMs, 10000)
        XCTAssertEqual(data.lines[1].text, "多时间戳合成行")
        XCTAssertEqual(data.lines[2].startMs, 20000, "同文本复制第二时间戳")
        XCTAssertEqual(data.lines[3].startMs, 15000)
        XCTAssertEqual(data.lines[3].text, "第三行合成歌词")
    }

    /// 解析宽容（D9）：`[m:ss]`/`[mm:ss.SS]`/`[mm:ss:SSS]`/`[mm:ss:xx]`/A9 四位截断。
    func testTolerantTimestamps() {
        XCTAssertEqual(LrcParser.parse("[1:2.5]文本").lines.first?.startMs, 62500)
        XCTAssertEqual(LrcParser.parse("[00:05.05]文本").lines.first?.startMs, 5050)
        XCTAssertEqual(LrcParser.parse("[00:05.005]文本").lines.first?.startMs, 5005)
        XCTAssertEqual(LrcParser.parse("[00:05:05]文本").lines.first?.startMs, 5050)
        XCTAssertEqual(LrcParser.parse("[00:05.0000]合成宽容行").lines.first?.startMs, 5000)
    }

    /// 行后缀 `" / "` 拆分默认关（S7 D6）。
    func testLineSuffixTranslationDefaultOff() {
        let data = LrcParser.parse("[00:05.00]原文 / 译文")
        XCTAssertEqual(data.lines.first?.text, "原文 / 译文")
        XCTAssertNil(data.lines.first?.translation)

        let enabled = LrcParser.parse(
            "[00:05.00]原文 / 译文",
            options: LrcParseOptions(lineSuffixTranslationEnabled: true)
        )
        XCTAssertEqual(enabled.lines.first?.text, "原文")
        XCTAssertEqual(enabled.lines.first?.translation, "译文")
    }

    /// 脏输入不崩（S6 §2.1-2）。
    func testDirtyInput() {
        XCTAssertTrue(LrcParser.parse("").lines.isEmpty)
        XCTAssertEqual(LrcParser.parse("\u{FEFF}[00:05.00]行").lines.count, 1)
        XCTAssertEqual(LrcParser.parse("[offset:250]\n[00:05.00]行").offsetMs, 250)
    }
}

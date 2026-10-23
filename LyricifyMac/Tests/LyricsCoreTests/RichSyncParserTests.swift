import XCTest
@testable import LyricsCore

/// Musixmatch richsync 解析测试（S1 §2.6；S6 §2.1-4 取整一致性）。
final class RichSyncParserTests: XCTestCase {
    /// 夹具：词起点 = ts+o、词终点 = 下一词起点、末词 = te（A6 舍入）。
    func testBasicFixture() throws {
        let data = try RichSyncParser.parse(FixtureLoader.load("musixmatch_richsync.json"))
        XCTAssertEqual(data.source, .richSync)
        XCTAssertEqual(data.syncLevel, .syllableSynced)
        XCTAssertEqual(data.lines.count, 2)
        let first = data.lines[0]
        XCTAssertEqual(first.startMs, 0)
        XCTAssertEqual(first.endMs, 3000)
        XCTAssertEqual(first.syllables?.map(\.startMs), [0, 1000, 2000])
        XCTAssertEqual(first.syllables?.map(\.durationMs), [1000, 1000, 1000])
        let second = data.lines[1]
        XCTAssertEqual(second.syllables?.map(\.startMs), [4000, 5200, 6100])
        XCTAssertEqual(second.syllables?.map(\.durationMs), [1200, 900, 900])
    }

    /// `subtitle_body` LRC 形态走 LRC 解析（S1 §2.6）。
    func testSubtitleBodyLRCForm() {
        let raw = "{\"track\":{\"subtitles\":{\"subtitle_body\":\"[00:01.00]行文本\"}}}"
        let data = RichSyncParser.parse(raw)
        XCTAssertEqual(data.source, .richSync)
        XCTAssertEqual(data.lines.count, 1)
        XCTAssertEqual(data.lines[0].startMs, 1000)
        XCTAssertEqual(data.lines[0].text, "行文本")
    }

    /// 脏输入不崩。
    func testDirtyInput() {
        XCTAssertEqual(RichSyncParser.parse("").lines.count, 0)
        XCTAssertEqual(RichSyncParser.parse("[]").lines.count, 0)
    }
}

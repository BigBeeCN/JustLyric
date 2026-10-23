import XCTest
@testable import LyricsCore

/// LyricifySyllable/LyricifyLines 解析测试（S1 §2.8–2.9；S6 §2.1-1/-5）。
final class LyricifyParsersTests: XCTestCase {
    /// 夹具：[3] 主行 + [6] 副行 → subLine（S6 §2.1-5）。
    func testSyllableFixture() throws {
        let data = try LyricifySyllableParser.parse(FixtureLoader.load("lyricify_syllable.txt"))
        XCTAssertEqual(data.source, .lyricifySyllable)
        XCTAssertEqual(data.syncLevel, .syllableSynced)
        XCTAssertEqual(data.lines.count, 1, "副行挂 subLine 而非独立行")
        let main = data.lines[0]
        XCTAssertEqual(main.startMs, 0)
        XCTAssertEqual(main.endMs, 3000)
        XCTAssertEqual(main.alignment, .center)
        XCTAssertEqual(main.syllables?.map(\.text), ["第一", "行歌", "词"])
        XCTAssertEqual(main.syllables?.map(\.startMs), [0, 500, 1000])

        let sub = try XCTUnwrap(main.subLine)
        XCTAssertEqual(sub.startMs, 0)
        XCTAssertEqual(sub.endMs, 2500)
        XCTAssertEqual(sub.alignment, .center)
        XCTAssertEqual(sub.syllables?.map(\.text), ["背景", "人声", "词"])
    }

    /// 行标 [3]–[8] → alignment 映射（S6 §2.1-5）。
    func testAlignmentMapping() {
        let raw = """
        [4](0,1000)左(0,500)行(500,500)
        [7](0,1000)左副(0,500)行(500,500)
        [5](2000,1000)右(0,500)行(500,500)
        [8](2000,1000)右副(0,500)行(500,500)
        """
        let data = LyricifySyllableParser.parse(raw)
        XCTAssertEqual(data.lines.count, 2)
        XCTAssertEqual(data.lines[0].alignment, .left)
        XCTAssertEqual(data.lines[0].subLine?.alignment, .left)
        XCTAssertEqual(data.lines[1].alignment, .right)
        XCTAssertEqual(data.lines[1].subLine?.alignment, .right)
    }

    /// 括号开头行 → isBackgroundVocal（S1 §2.8）。
    func testBracketedBackgroundVocal() {
        let data = LyricifySyllableParser.parse("[3](0,1000)(背景)(0,500)")
        XCTAssertEqual(data.lines[0].isBackgroundVocal, true)
    }

    /// LyricifyLines：标记 + 行形态（S1 §2.9）。
    func testLinesFixture() throws {
        let data = try LyricifyLinesParser.parse(FixtureLoader.load("lyricify_lines.txt"))
        XCTAssertEqual(data.source, .lyricifyLines)
        XCTAssertEqual(data.syncLevel, .lineSynced)
        XCTAssertEqual(data.lines.count, 2)
        XCTAssertEqual(data.lines[0].startMs, 0)
        XCTAssertEqual(data.lines[0].endMs, 3000)
        XCTAssertEqual(data.lines[0].text, "第一行合成文本")
        XCTAssertEqual(data.lines[1].startMs, 4000)
    }
}

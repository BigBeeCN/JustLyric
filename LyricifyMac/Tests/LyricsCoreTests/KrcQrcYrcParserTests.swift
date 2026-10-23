import XCTest
@testable import LyricsCore

/// KRC/QRC/YRC 解析测试（S1 §2.2–2.4；S6 §2.1-1/-4/-6）。
final class KrcQrcYrcParserTests: XCTestCase {
    /// KRC：元信息剥离 + 词绝对时间（S6 §2.1-4）。
    func testKrcFixture() throws {
        let data = try KrcParser.parse(FixtureLoader.load("krc_word.krc"))
        XCTAssertEqual(data.source, .krc)
        XCTAssertEqual(data.syncLevel, .syllableSynced)
        XCTAssertEqual(data.lines.count, 2, "元信息头行不入行")
        let first = data.lines[0]
        XCTAssertEqual(first.startMs, 0)
        XCTAssertEqual(first.endMs, 3000)
        XCTAssertEqual(first.syllables?.map(\.text), ["第一", "行歌", "词"])
        XCTAssertEqual(first.syllables?.map(\.startMs), [0, 300, 700])
        XCTAssertEqual(first.syllables?.map(\.durationMs), [300, 400, 600])
        let second = data.lines[1]
        XCTAssertEqual(second.startMs, 4000)
        XCTAssertEqual(second.syllables?.map(\.startMs), [4000, 4500, 5000])
    }

    /// QRC：词偏移相对行起始（S6 §2.1-4）。
    func testQrcFixture() throws {
        let data = try QrcParser.parse(FixtureLoader.load("qrc_word.qrc"))
        XCTAssertEqual(data.source, .qrc)
        XCTAssertEqual(data.lines.count, 2)
        XCTAssertEqual(data.lines[0].syllables?.map(\.startMs), [0, 300, 700])
        XCTAssertEqual(data.lines[0].syllables?.map(\.durationMs), [300, 400, 600])
        XCTAssertEqual(data.lines[1].syllables?.map(\.startMs), [4000, 4500, 5000])
    }

    /// QRC XML 大包：LyricContent 提取 + 拆行。
    func testQrcXmlEnvelope() {
        let raw = "<Lyric_1 Artist=\"合成\" LyricContent=\"[0,3000]第一(0,300)词(300,400)\\n[4000,2000]第二(0,500)词(500,500)\"/>"
        let data = QrcParser.parse(raw)
        XCTAssertEqual(data.lines.count, 2)
        XCTAssertEqual(data.lines[0].syllables?.map(\.text), ["第一", "词"])
        XCTAssertEqual(data.lines[1].startMs, 4000)
        XCTAssertEqual(data.lines[1].endMs, 6000)
    }

    /// YRC：credits 提取 + 三元组（S6 §2.1-6/-4）。
    func testYrcFixture() throws {
        let data = try YrcParser.parse(FixtureLoader.load("yrc_word.yrc"))
        XCTAssertEqual(data.source, .yrc)
        XCTAssertEqual(data.writer, "合成作词甲、合成作曲乙")
        XCTAssertEqual(data.lines.count, 2, "credits 行不误吞")
        XCTAssertEqual(data.lines[0].syllables?.map(\.startMs), [0, 300, 700])
        XCTAssertEqual(data.lines[1].syllables?.map(\.text), ["第二", "行歌", "词"])
    }

    /// YRC：n 与 text.count 不一致以 text 为准。
    func testYrcCharCountMismatchUsesText() {
        let data = YrcParser.parse("[0,1000](0,300,9)第一(300,400,1)词")
        XCTAssertEqual(data.lines[0].syllables?.map(\.text), ["第一", "词"])
        XCTAssertEqual(data.lines[0].text, "第一词")
    }
}

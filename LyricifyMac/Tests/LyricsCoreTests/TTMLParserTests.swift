import XCTest
@testable import LyricsCore

/// TTML 解析测试（S1 §2.5；S6 §2.1-1）。
final class TTMLParserTests: XCTestCase {
    /// 夹具：行 + 词 + 翻译 span + agent。
    func testBasicFixture() throws {
        let data = try TTMLParser.parse(FixtureLoader.load("ttml_basic.ttml"))
        XCTAssertEqual(data.source, .ttml)
        XCTAssertEqual(data.syncLevel, .syllableSynced)
        XCTAssertEqual(data.lines.count, 1)
        let line = data.lines[0]
        XCTAssertEqual(line.startMs, 0)
        XCTAssertEqual(line.endMs, 3000)
        XCTAssertEqual(line.syllables?.map(\.text), ["词一", "词二"])
        XCTAssertEqual(line.syllables?.map(\.startMs), [0, 1500])
        XCTAssertEqual(line.syllables?.map(\.durationMs), [1500, 1500])
        XCTAssertEqual(line.translation, "合成译文行")
        XCTAssertEqual(data.writer, "合成作词甲、合成作曲乙")
    }

    /// 时间格式三种（S1 §2.5）。
    func testTimeFormats() {
        XCTAssertEqual(TTMLParser.timeMs("01:02.5"), 62500)
        XCTAssertEqual(TTMLParser.timeMs("01:02:03.5"), 3_723_500)
        XCTAssertEqual(TTMLParser.timeMs("1.5"), 1500)
        XCTAssertEqual(TTMLParser.timeMs("2s"), 2000)
    }

    /// dur 形态与行级兜底。
    func testDurAndLineSyncedFallback() {
        let raw = """
        <tt xmlns="http://www.w3.org/ns/ttml">
          <body><div>
            <p begin="0s" end="3s">
              <span begin="0s" dur="1s">词一</span>
              <span begin="1s" dur="2s">词二</span>
            </p>
            <p begin="4s" end="7s">整行文本</p>
          </div></body>
        </tt>
        """
        let data = TTMLParser.parse(raw)
        XCTAssertEqual(data.lines[0].syllables?.map(\.durationMs), [1000, 2000])
        XCTAssertEqual(data.lines[1].syllables?.count, 1)
        XCTAssertEqual(data.lines[1].text, "整行文本")
    }
}

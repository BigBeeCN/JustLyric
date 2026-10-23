import XCTest
@testable import LyricsCore

/// 生成 round-trip 测试（S1 §4；S6 §2.2-1 数值不漂移、§2.2-2 副行往返）。
final class GeneratorRoundTripTests: XCTestCase {
    /// 提取行/词时序形状用于比对。
    private func shape(_ data: LyricsData) -> [[Int]] {
        data.lines.map { line in
            var values = [line.startMs ?? -1, line.endMs ?? -1]
            for syllable in line.syllables ?? [] {
                values.append(syllable.startMs)
                values.append(syllable.durationMs)
            }
            return values
        }
    }

    /// LRC round-trip（多时间戳展开后数值稳定）。
    func testLrcRoundTrip() throws {
        let first = try LrcParser.parse(FixtureLoader.load("lrc_basic.lrc"))
        let second = LrcParser.parse(LrcGenerator.generate(first))
        XCTAssertEqual(shape(second).map { $0[0] }, shape(first).map { $0[0] }, "±0ms")
        XCTAssertEqual(second.offsetMs, first.offsetMs)
        XCTAssertEqual(second.trackMeta?.title, first.trackMeta?.title)
        XCTAssertEqual(second.writer, first.writer)
    }

    /// KRC round-trip。
    func testKrcRoundTrip() throws {
        let first = try KrcParser.parse(FixtureLoader.load("krc_word.krc"))
        let second = KrcParser.parse(KrcGenerator.generate(first))
        XCTAssertEqual(shape(second), shape(first), "±0ms")
    }

    /// QRC round-trip。
    func testQrcRoundTrip() throws {
        let first = try QrcParser.parse(FixtureLoader.load("qrc_word.qrc"))
        let second = QrcParser.parse(QrcGenerator.generate(first))
        XCTAssertEqual(shape(second), shape(first), "±0ms")
    }

    /// YRC round-trip（含 credits writer）。
    func testYrcRoundTrip() throws {
        let first = try YrcParser.parse(FixtureLoader.load("yrc_word.yrc"))
        let second = YrcParser.parse(YrcGenerator.generate(first))
        XCTAssertEqual(shape(second), shape(first), "±0ms")
        XCTAssertEqual(second.writer, first.writer)
    }

    /// LyricifySyllable round-trip（S6 §2.2-2：副行 + 3–8 行标往返）。
    func testLyricifySyllableRoundTrip() throws {
        let first = try LyricifySyllableParser.parse(FixtureLoader.load("lyricify_syllable.txt"))
        let second = LyricifySyllableParser.parse(LyricifySyllableGenerator.generate(first))
        XCTAssertEqual(shape(second), shape(first), "±0ms")
        XCTAssertEqual(second.lines[0].subLine?.text, first.lines[0].subLine?.text, "副行往返保留")
        XCTAssertEqual(second.lines[0].subLine?.startMs, first.lines[0].subLine?.startMs)

        // 3–8 行标正确往返（左/右对齐 + 副行）。
        let aligned = LyricifySyllableParser.parse(
            "[4](0,1000)左(0,500)行(500,500)\n[7](0,1000)左副(0,500)行(500,500)"
        )
        let reAligned = LyricifySyllableParser.parse(LyricifySyllableGenerator.generate(aligned))
        XCTAssertEqual(reAligned.lines[0].alignment, .left)
        XCTAssertEqual(reAligned.lines[0].subLine?.alignment, .left)
    }

    /// LyricifyLines round-trip（副行内嵌/独立两模式）。
    func testLyricifyLinesRoundTrip() {
        let main = LyricsLine(
            startMs: 0,
            endMs: 3000,
            text: "主行",
            subLine: LyricsLine(startMs: 0, endMs: 1500, text: "副行")
        )
        let data = LyricsData(lines: [main], syncLevel: .lineSynced)

        let independent = LyricifyLinesParser.parse(
            LyricifyLinesGenerator.generate(data, subLinesOutputMode: .independent)
        )
        XCTAssertEqual(independent.lines.count, 2)
        XCTAssertEqual(independent.lines[1].text, "副行")

        let embedded = LyricifyLinesParser.parse(
            LyricifyLinesGenerator.generate(data, subLinesOutputMode: .embedded)
        )
        XCTAssertEqual(embedded.lines.count, 1)
        XCTAssertEqual(embedded.lines[0].text, "主行 / 副行")
    }
}

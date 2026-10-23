import XCTest
@testable import LyricsCore

/// 长句切分测试（S1 §5 + S2 §3 #6；S6 §2.4-5 时间守恒）。
final class SentenceSplitterTests: XCTestCase {
    /// 行级切分：按标点切、时间按比例分配、总时长守恒。
    func testLineSyncedSplitConservesTime() {
        let line = LyricsLine(
            startMs: 0,
            endMs: 2000,
            text: "一二三四五，六七八九十，十一十二。"
        )
        let data = SentenceSplitter.splitLongChineseSentences(
            LyricsData(lines: [line]),
            maxChars: 8
        )
        XCTAssertGreaterThan(data.lines.count, 1)
        for segment in data.lines {
            XCTAssertLessThanOrEqual(segment.text.count, 8)
        }
        let total = data.lines.reduce(0) { $0 + (($1.endMs ?? 0) - ($1.startMs ?? 0)) }
        XCTAssertEqual(total, 2000, "总时长守恒")
        XCTAssertEqual(data.lines.first?.startMs, 0)
        XCTAssertEqual(data.lines.last?.endMs, 2000)
    }

    /// 逐字切分：词块整体归属、无重叠、时长守恒。
    func testSyllableSplitConservesTime() {
        let syllables = (0 ..< 10).map {
            Syllable(text: "字\($0)", startMs: $0 * 100, durationMs: 100)
        }
        let line = LyricsLine(
            startMs: 0,
            endMs: 1000,
            text: "字0字1字2字3字4字5字6字7字8字9",
            syllables: syllables
        )
        let data = SentenceSplitter.splitLongChineseSentences(
            LyricsData(lines: [line]),
            maxChars: 6
        )
        let total = data.lines.flatMap { $0.syllables ?? [] }.reduce(0) { $0 + $1.durationMs }
        XCTAssertEqual(total, 1000, "词时长守恒")
        var previousEnd = -1
        for syllable in data.lines.flatMap({ $0.syllables ?? [] }) {
            XCTAssertGreaterThanOrEqual(syllable.startMs, previousEnd, "词块不重叠")
            previousEnd = syllable.startMs + syllable.durationMs
        }
    }

    /// 翻译分配（A4/D17）：无切点挂首行。
    func testTranslationWithoutCutGoesToFirstSegment() {
        let line = LyricsLine(
            startMs: 0,
            endMs: 3000,
            text: "一二三四五，六七八九十，十一十二。",
            translation: "NoPunctuationTranslation"
        )
        let data = SentenceSplitter.splitLongChineseSentences(
            LyricsData(lines: [line]),
            maxChars: 8
        )
        XCTAssertEqual(data.lines.first?.translation, "NoPunctuationTranslation")
        XCTAssertNil(data.lines.last?.translation)
    }

    /// 短句不切。
    func testShortLineUnchanged() {
        let line = LyricsLine(startMs: 0, endMs: 100, text: "短句")
        let data = SentenceSplitter.splitLongChineseSentences(LyricsData(lines: [line]))
        XCTAssertEqual(data.lines.count, 1)
        XCTAssertEqual(data.lines[0].text, "短句")
    }
}

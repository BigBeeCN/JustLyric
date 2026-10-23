import XCTest
@testable import LyricsCore

/// 领域模型测试（S1 §1；S6 §2.1-1 golden 载体；S7 D8 序列化规范）。
final class ModelCodingTests: XCTestCase {
    /// 构造全字段样例数据。
    private func makeSample() -> LyricsData {
        let word = Syllable(text: "词", startMs: 0, durationMs: 300, subSyllables: nil)
        let line = LyricsLine(
            startMs: 0,
            endMs: 1000,
            text: "第一行",
            translation: "first line",
            pronunciation: nil,
            syllables: [word],
            subLine: LyricsLine(startMs: 0, endMs: 500, text: "背景声"),
            alignment: .left,
            isBackgroundVocal: false
        )
        return LyricsData(
            lines: [line],
            syncLevel: .syllableSynced,
            language: ["zh"],
            offsetMs: 100,
            titleLines: 1,
            endingLines: 0,
            writer: "合成作词甲",
            isInstrumental: false,
            source: .yrc,
            raw: nil
        )
    }

    /// golden 序列化规范：camelCase、sortedKeys+prettyPrinted、nil 省略（S7 D8）。
    func testGoldenEncodingSpec() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let json = try encoder.encode(makeSample())
        let text = try XCTUnwrap(String(data: json, encoding: .utf8))
        XCTAssertFalse(text.contains("null"), "nil 字段必须省略而非输出 null")
        XCTAssertTrue(text.contains("\"syncLevel\""), "必须为 camelCase 键")
        XCTAssertTrue(text.contains("offsetMs"), "必须含毫秒 Int 字段")
    }

    /// Codable 自往返无损。
    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = try encoder.encode(makeSample())
        let decoded = try JSONDecoder().decode(LyricsData.self, from: json)
        XCTAssertEqual(decoded.lines.count, 1)
        XCTAssertEqual(decoded.lines[0].text, "第一行")
        XCTAssertEqual(decoded.lines[0].translation, "first line")
        XCTAssertEqual(decoded.lines[0].alignment, .left)
        XCTAssertEqual(decoded.lines[0].syllables?.first?.text, "词")
        XCTAssertEqual(decoded.lines[0].subLine?.text, "背景声")
        XCTAssertEqual(decoded.offsetMs, 100)
        XCTAssertEqual(decoded.writer, "合成作词甲")
        XCTAssertEqual(decoded.syncLevel, .syllableSynced)
        XCTAssertEqual(decoded.source, .yrc)
        XCTAssertNil(decoded.raw)
    }

    /// `LyricsAlignment` 默认 `.center`（S1 §1）。
    func testDefaultAlignmentIsCenter() {
        let line = LyricsLine(text: "行")
        XCTAssertEqual(line.alignment, .center)
    }

    /// D1 命名定案：LyricsRawType 10 个 case。
    func testRawTypeCases() {
        let expected: [LyricsRawType] = [
            .lrc, .krc, .qrc, .yrc, .ttml,
            .richSync, .spotifyColorLyrics, .lyricifySyllable, .lyricifyLines, .unknown,
        ]
        XCTAssertEqual(expected.count, 10)
        XCTAssertEqual(LyricsRawType(rawValue: "richSync"), .richSync)
        XCTAssertNil(LyricsRawType(rawValue: "appleJson"), "AppleJson 不设 case（S7 D1）")
    }

    /// A6/D17：秒→毫秒全局换算标准 round-half-away-from-zero。
    func testSecondsToMillisecondsRounding() {
        XCTAssertEqual(Timing.milliseconds(fromSeconds: 1.2345), 1235)
        XCTAssertEqual(Timing.milliseconds(fromSeconds: 1.2344), 1234)
        XCTAssertEqual(Timing.milliseconds(fromSeconds: 0.0005), 1)
        XCTAssertEqual(Timing.milliseconds(fromSeconds: -0.0005), -1)
    }

    /// 时间戳宽容换算（A9/D18）：分数 1–4 位补零/截断。
    func testTimestampTolerance() {
        XCTAssertEqual(Timing.milliseconds(minutes: 0, seconds: 5, fractionDigits: nil), 5000)
        XCTAssertEqual(Timing.milliseconds(minutes: 0, seconds: 5, fractionDigits: "5"), 5500)
        XCTAssertEqual(Timing.milliseconds(minutes: 0, seconds: 5, fractionDigits: "05"), 5050)
        XCTAssertEqual(Timing.milliseconds(minutes: 0, seconds: 5, fractionDigits: "0000"), 5000)
    }

    /// D19：additionalInfo 往返且 nil 省略。
    func testAdditionalInfoCoding() throws {
        let info = SpotifyAdditionalInfo(
            syncType: SpotifySyncType(apiValue: "SYLLABLE_SYNCED"),
            alternatives: [SpotifyAlternative(language: "zh", lines: ["备选行"], isRtlLanguage: false)]
        )
        XCTAssertEqual(SpotifySyncType(apiValue: "LINE_SYNCED"), .lineSynced)
        XCTAssertEqual(SpotifySyncType(apiValue: "SOMETHING"), .unknown)
        var data = makeSample()
        data.additionalInfo = info
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoded = try JSONDecoder().decode(
            LyricsData.self,
            from: encoder.encode(data)
        )
        XCTAssertEqual(decoded.additionalInfo?.alternatives.first?.lines, ["备选行"])
        XCTAssertEqual(decoded.additionalInfo?.syncType, .syllableSynced)
        XCTAssertNil(makeSample().additionalInfo)
    }
}

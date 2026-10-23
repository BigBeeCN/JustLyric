import XCTest
@testable import LyricsCore

/// Spotify ColorLyrics 解析测试（S1 §2.7 D13 字段；S7 D19 语义）。
final class SpotifyParserTests: XCTestCase {
    /// 夹具：numChars 切词、行级兜底、alternatives 仅入 additionalInfo。
    func testBasicFixture() throws {
        let data = try SpotifyLyricsParser.parse(FixtureLoader.load("spotify_colorlyrics.json"))
        XCTAssertEqual(data.source, .spotifyColorLyrics)
        XCTAssertEqual(data.syncLevel, .syllableSynced)

        // 行 1：词文本按 numChars 从 words 截取（D13）。
        let first = data.lines[0]
        XCTAssertEqual(first.syllables?.map(\.text), ["词一", "词二"])
        XCTAssertEqual(first.syllables?.map(\.startMs), [0, 1500])
        XCTAssertEqual(first.syllables?.map(\.durationMs), [1500, 1500])

        // 行 2：无 syllables 行级兜底（D19）。
        let second = data.lines[1]
        XCTAssertNil(second.syllables)
        XCTAssertEqual(second.text, "第三行合成词")
        XCTAssertEqual(second.startMs, 4000)
        XCTAssertEqual(second.endMs, 7000)

        // D19：alternatives 不映射行字段。
        for line in data.lines {
            XCTAssertNil(line.subLine, "D19：禁止挂 subLine")
            XCTAssertFalse(line.isBackgroundVocal, "D19：禁止挂 isBackgroundVocal")
        }
        let info = try XCTUnwrap(data.additionalInfo)
        XCTAssertEqual(info.syncType, .syllableSynced)
        XCTAssertEqual(info.alternatives.count, 1)
        XCTAssertEqual(info.alternatives[0].language, "zh")
        XCTAssertEqual(info.alternatives[0].lines, ["替代背景人声一", "替代背景人声二"])
    }

    /// D19：`endTime==0` 视无时序行；syncType 映射。
    func testUntimedLineAndSyncTypeMapping() {
        let raw = """
        {"lyrics":{"syncType":"LINE_SYNCED","lines":[
          {"startTimeMs":"0","endTimeMs":"0","words":"无时序行","syllables":[]}
        ]}}
        """
        let data = SpotifyLyricsParser.parse(raw)
        XCTAssertEqual(data.syncLevel, .lineSynced)
        XCTAssertEqual(data.additionalInfo?.syncType, .lineSynced)
        XCTAssertNil(data.lines[0].startMs)
        XCTAssertNil(data.lines[0].endMs)
        XCTAssertEqual(data.lines[0].text, "无时序行")
    }

    /// A2/D17：数字形态时间字段容忍。
    func testNumericTimeTolerance() {
        let raw = """
        {"lyrics":{"syncType":"SYLLABLE_SYNCED","lines":[
          {"startTimeMs":0,"endTimeMs":3000,"words":"词一",
           "syllables":[{"startTimeMs":0,"endTimeMs":3000,"numChars":2}]}
        ]}}
        """
        let data = SpotifyLyricsParser.parse(raw)
        XCTAssertEqual(data.lines[0].syllables?.first?.text, "词一")
        XCTAssertEqual(data.lines[0].syllables?.first?.durationMs, 3000)
    }
}

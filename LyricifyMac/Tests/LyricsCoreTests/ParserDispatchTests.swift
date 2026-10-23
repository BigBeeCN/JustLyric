import XCTest
@testable import LyricsCore

/// parse 分发测试（S1 §5；S6 §2.1-1/-2；D20/D21 纯文本兜底）。
final class ParserDispatchTests: XCTestCase {
    /// 判型分发：夹具各自进入正确解析器。
    func testDispatchByDetection() throws {
        XCTAssertEqual(try parse(FixtureLoader.load("lrc_basic.lrc")).source, .lrc)
        XCTAssertEqual(try parse(FixtureLoader.load("krc_word.krc")).source, .krc)
        XCTAssertEqual(try parse(FixtureLoader.load("qrc_word.qrc")).source, .qrc)
        XCTAssertEqual(try parse(FixtureLoader.load("yrc_word.yrc")).source, .yrc)
        XCTAssertEqual(try parse(FixtureLoader.load("ttml_basic.ttml")).source, .ttml)
        XCTAssertEqual(try parse(FixtureLoader.load("musixmatch_richsync.json")).source, .richSync)
        XCTAssertEqual(
            try parse(FixtureLoader.load("spotify_colorlyrics.json")).source,
            .spotifyColorLyrics
        )
        XCTAssertEqual(try parse(FixtureLoader.load("lyricify_syllable.txt")).source, .lyricifySyllable)
        XCTAssertEqual(try parse(FixtureLoader.load("lyricify_lines.txt")).source, .lyricifyLines)
    }

    /// D20/D21：Unknown → 纯文本行 + `.unsynced`；isInstrumental 照常工作。
    func testUnknownPlainTextFallback() throws {
        let data = try parse(FixtureLoader.load("instrumental.txt"))
        XCTAssertEqual(data.source, .unknown)
        XCTAssertEqual(data.syncLevel, .unsynced)
        XCTAssertEqual(data.lines.count, 1)
        XCTAssertTrue(LyricsUtilities.isInstrumental(data))
    }

    /// 显式指定 type 覆盖判型。
    func testExplicitTypeOverride() {
        let data = parse("[00:05.00]行文本", type: .lrc)
        XCTAssertEqual(data.source, .lrc)
        XCTAssertEqual(data.lines.first?.startMs, 5000)
    }
}

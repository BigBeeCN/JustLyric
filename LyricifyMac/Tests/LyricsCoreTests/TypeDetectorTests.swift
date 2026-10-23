import XCTest
@testable import LyricsCore

/// 类型判别测试（S1 §3；S6 §2.1-2 含脏输入与 D9 负例）。
final class TypeDetectorTests: XCTestCase {
    /// 10 份夹具判型正确（S6 §2.1-2）。
    func testDetectsAllFixtureTypes() throws {
        XCTAssertEqual(try detectType(FixtureLoader.load("lrc_basic.lrc")), .lrc)
        XCTAssertEqual(try detectType(FixtureLoader.load("krc_word.krc")), .krc)
        XCTAssertEqual(try detectType(FixtureLoader.load("qrc_word.qrc")), .qrc)
        XCTAssertEqual(try detectType(FixtureLoader.load("yrc_word.yrc")), .yrc)
        XCTAssertEqual(try detectType(FixtureLoader.load("ttml_basic.ttml")), .ttml)
        XCTAssertEqual(try detectType(FixtureLoader.load("musixmatch_richsync.json")), .richSync)
        XCTAssertEqual(try detectType(FixtureLoader.load("spotify_colorlyrics.json")), .spotifyColorLyrics)
        XCTAssertEqual(try detectType(FixtureLoader.load("lyricify_syllable.txt")), .lyricifySyllable)
        XCTAssertEqual(try detectType(FixtureLoader.load("lyricify_lines.txt")), .lyricifyLines)
        XCTAssertEqual(try detectType(FixtureLoader.load("instrumental.txt")), .unknown)
    }

    /// 混合/脏输入不崩（空、CRLF、BOM、尾空白）。
    func testDirtyInputDoesNotCrash() {
        XCTAssertEqual(detectType(""), .unknown)
        XCTAssertEqual(detectType("\r\n\r\n"), .unknown)
        XCTAssertEqual(detectType("\u{FEFF}"), .unknown)
        XCTAssertEqual(detectType("   \t  "), .unknown)
        XCTAssertEqual(detectType("[00:05.00]行文本   \t  "), .lrc)
        XCTAssertEqual(detectType("[00:05.00]行一\r\n[00:10.00]行二\r\n"), .lrc, "CRLF 换行不干扰判型")
    }

    /// BOM 前缀容忍（输入卫生，不影响判型正则）。
    func testBOMPrefixedLRCStillDetects() throws {
        let lrc = try FixtureLoader.load("lrc_basic.lrc")
        XCTAssertEqual(detectType("\u{FEFF}" + lrc), .lrc)
    }

    /// D9 负例：宽容可解析（拟态 4 位毫秒时间戳，解析器可截断）但判型正则不匹配 → 不误判 LRC（S7 A9 待批形态）。
    func testTolerantButUndetectableFormIsNotLRC() {
        XCTAssertEqual(detectType("[00:05.0000]合成宽容行"), .unknown)
    }

    /// QRC XML 大包（ignoreCase）。
    func testQrcFullEnvelope() {
        let raw = "<Lyric_1 Artist=\"合成\" LyricContent=\"[0,3000]第一(0,300)词(300,400)\"/>"
        XCTAssertEqual(detectType(raw), .qrc)
        let lower = "<lyric_1 lyriccontent=\"[0,3000]第一(0,300)词(300,400)\"/>"
        XCTAssertEqual(detectType(lower), .qrc, "大包判型 ignoreCase（S1 §3）")
    }

    /// 判型顺序：KRC 优先于 QRC 行形态（S1 §3 顺序）。
    func testPriorityOrder() {
        let mixed = "[0,3000]第一(0,300)词(300,400)\n[4000,3000]<0,500,0>第二<500,500,0>词"
        XCTAssertEqual(detectType(mixed), .krc, "KRC 行优先级最高（判定顺序）")
    }

    /// LyricifyLines 行形态（无标记、无逐字时序）。
    func testLyricifyLinesForm() {
        XCTAssertEqual(detectType("[0,3000]第一行合成文本\n[4000,7000]第二行合成文本"), .lyricifyLines)
    }
}

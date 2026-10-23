import XCTest
@testable import LyricsCore

/// 纯函数工具测试（S1 §5；S6 §2.4-2/-3）。
final class UtilitiesTests: XCTestCase {
    /// CJK 码位判定（S2 §3 #1）。
    func testDetectCJK() {
        XCTAssertTrue(LyricsUtilities.detectCJK("漢字"))
        XCTAssertTrue(LyricsUtilities.detectCJK("ひらがな"))
        XCTAssertTrue(LyricsUtilities.detectCJK("カタカナ"))
        XCTAssertFalse(LyricsUtilities.detectCJK("abc"))
        XCTAssertFalse(LyricsUtilities.detectCJK("한글"), "谚文不在指定码位")
    }

    /// 偏移平移：行/词/副行统一（S6 §2.4-3；A5/D17 正值=延后）。
    func testApplyOffset() {
        let sub = LyricsLine(
            startMs: 100,
            endMs: 200,
            text: "副",
            syllables: [Syllable(text: "副", startMs: 100, durationMs: 100)]
        )
        let main = LyricsLine(
            startMs: 0,
            endMs: 1000,
            text: "主",
            translation: "译",
            syllables: [Syllable(text: "主", startMs: 0, durationMs: 1000)]
        )
        main.subLine = sub
        let data = LyricsData(lines: [main], source: .lrc)

        let shifted = LyricsUtilities.applyOffset(data, ms: 500)
        XCTAssertEqual(shifted.lines[0].startMs, 500)
        XCTAssertEqual(shifted.lines[0].endMs, 1500)
        XCTAssertEqual(shifted.lines[0].syllables?.first?.startMs, 500)
        XCTAssertEqual(shifted.lines[0].subLine?.startMs, 600)
        XCTAssertEqual(shifted.lines[0].subLine?.syllables?.first?.startMs, 600)

        let back = LyricsUtilities.applyOffset(shifted, ms: -500)
        XCTAssertEqual(back.lines[0].startMs, 0)
        XCTAssertEqual(back.lines[0].subLine?.startMs, 100)
    }

    /// 降级：丢 syllables，保 translation/subLine。
    func testDowngradeKeepsTranslationAndSubLine() {
        let main = LyricsLine(
            startMs: 0,
            endMs: 1000,
            text: "主",
            translation: "译",
            syllables: [Syllable(text: "主", startMs: 0, durationMs: 1000)]
        )
        main.subLine = LyricsLine(
            startMs: 0,
            endMs: 500,
            text: "副",
            syllables: [Syllable(text: "副", startMs: 0, durationMs: 500)]
        )
        let downgraded = LyricsUtilities.downgradeToLineSynced(
            LyricsData(lines: [main], syncLevel: .syllableSynced)
        )
        XCTAssertEqual(downgraded.syncLevel, .lineSynced)
        XCTAssertNil(downgraded.lines[0].syllables)
        XCTAssertEqual(downgraded.lines[0].translation, "译")
        XCTAssertNil(downgraded.lines[0].subLine?.syllables)
        XCTAssertEqual(downgraded.lines[0].subLine?.text, "副")
    }

    /// 纯音乐判定：4 种文案（S6 §2.4-2）。
    func testIsInstrumental() {
        let texts = [
            "纯音乐，请欣赏",
            "此歌曲为没有填词的纯音乐，请您欣赏",
            "此歌曲为DJ舞曲，请您欣赏",
            "此歌曲为没有填词的DJ舞曲，请您欣赏",
        ]
        for text in texts {
            let data = LyricsData(lines: [LyricsLine(text: text)])
            XCTAssertTrue(LyricsUtilities.isInstrumental(data), text)
        }
        XCTAssertFalse(LyricsUtilities.isInstrumental(LyricsData(lines: [LyricsLine(text: "其他")])))
        XCTAssertFalse(
            LyricsUtilities.isInstrumental(
                LyricsData(lines: [LyricsLine(text: "纯音乐，请欣赏"), LyricsLine(text: "多行")])
            ),
            "非单行不判纯音乐"
        )
    }
}

import XCTest
@testable import LyricsCore

/// 优化管线测试（S2 §3；S6 §2.4-1/-3/-4/-5；D17 A1 约束、D6 attachTranslation）。
final class PipelineTests: XCTestCase {
    // MARK: - #1 mergeSyllables（S6 §2.4-1）

    /// 西文相邻音节合并为词。
    func testWesternMerge() {
        let syllables = [
            Syllable(text: "He", startMs: 0, durationMs: 100),
            Syllable(text: "llo", startMs: 100, durationMs: 200),
        ]
        let line = LyricsLine(startMs: 0, endMs: 300, text: "Hello", syllables: syllables)
        let merged = SyllableStages.mergeSyllables(LyricsData(lines: [line]))
        XCTAssertEqual(merged.lines[0].syllables?.count, 1)
        XCTAssertEqual(merged.lines[0].syllables?.first?.text, "Hello")
        XCTAssertEqual(merged.lines[0].syllables?.first?.startMs, 0)
        XCTAssertEqual(merged.lines[0].syllables?.first?.durationMs, 300)
        XCTAssertEqual(merged.lines[0].syllables?.first?.subSyllables?.count, 2)
    }

    /// CJK 不合并（含假名/汉字边界，S6 §2.4-1）。
    func testCJKNotMerged() {
        let cases: [[Syllable]] = [
            [Syllable(text: "漢", startMs: 0, durationMs: 100), Syllable(text: "字", startMs: 100, durationMs: 100)],
            [Syllable(text: "あ", startMs: 0, durationMs: 100), Syllable(text: "字", startMs: 100, durationMs: 100)],
            [Syllable(text: "漢", startMs: 0, durationMs: 100), Syllable(text: "字", startMs: 100, durationMs: 100)],
            [Syllable(text: "カ", startMs: 0, durationMs: 100), Syllable(text: "タ", startMs: 100, durationMs: 100)],
            [Syllable(text: "abc", startMs: 0, durationMs: 100), Syllable(text: "漢", startMs: 100, durationMs: 100)],
        ]
        for syllables in cases {
            let line = LyricsLine(startMs: 0, endMs: 200, text: "x", syllables: syllables)
            let merged = SyllableStages.mergeSyllables(LyricsData(lines: [line]))
            XCTAssertEqual(merged.lines[0].syllables?.count, 2, "CJK 侧不合并")
        }
    }

    /// 空白边界不合并。
    func testWhitespaceBoundaryNotMerged() {
        let syllables = [
            Syllable(text: "He", startMs: 0, durationMs: 100),
            Syllable(text: " llo", startMs: 100, durationMs: 100),
        ]
        let line = LyricsLine(startMs: 0, endMs: 200, text: "He llo", syllables: syllables)
        let merged = SyllableStages.mergeSyllables(LyricsData(lines: [line]))
        XCTAssertEqual(merged.lines[0].syllables?.count, 2)
    }

    // MARK: - #2 cleanInfoLines（D17 A1）

    /// title/ending 连续块识别 + writer 提取剥离 + 3 行上限（D17/A1）。
    func testCleanInfoLines() {
        let meta = TrackMeta(title: "合成曲名丙", artists: ["合成歌手甲"])
        let lines = [
            LyricsLine(text: "演唱：合成歌手甲"),
            LyricsLine(text: "合成曲名丙"),
            LyricsLine(text: "作词：合成作词甲"),
            LyricsLine(text: "正文第一行"),
            LyricsLine(text: "正文第二行"),
            LyricsLine(text: "合成歌手甲 感谢聆听"),
        ]
        let data = LyricsData(lines: lines, trackMeta: meta)
        let cleaned = TextStages.cleanInfoLines(data)
        XCTAssertEqual(cleaned.titleLines, 2, "auto：前部连续命中块")
        XCTAssertEqual(cleaned.endingLines, 1)
        XCTAssertEqual(cleaned.lines.map(\.text), ["正文第一行", "正文第二行"])
        XCTAssertEqual(cleaned.writer, "合成作词甲")

        // 3 行上限（D17：防误吞正文）。
        let capped = TextStages.cleanInfoLines(
            LyricsData(
                lines: (0 ..< 5).map { _ in LyricsLine(text: "合成曲名丙") } + [LyricsLine(text: "正文")],
                trackMeta: meta
            )
        )
        XCTAssertEqual(capped.titleLines, 3, "title 块最多前 3 行")
        XCTAssertEqual(capped.lines.count, 3)
    }

    /// 设置覆盖 auto（D17）。
    func testCleanInfoLinesOverride() {
        let meta = TrackMeta(title: "合成曲名丙")
        let lines = [
            LyricsLine(text: "合成曲名丙"),
            LyricsLine(text: "正文第一行"),
        ]
        let cleaned = TextStages.cleanInfoLines(
            LyricsData(lines: lines, trackMeta: meta),
            titleLinesOverride: 0
        )
        XCTAssertEqual(cleaned.titleLines, 0)
        XCTAssertEqual(cleaned.lines.count, 2, "覆盖 0 不剥离")
    }

    // MARK: - #4 偏移叠加（S6 §2.4-3；A5 正值=延后）

    /// 叠加顺序与符号：offsetMs + 源延迟 + 会话延迟。
    func testOffsetStacking() {
        let line = LyricsLine(
            startMs: 1000,
            endMs: 2000,
            text: "行",
            syllables: [Syllable(text: "行", startMs: 1000, durationMs: 1000)]
        )
        let data = LyricsData(lines: [line], offsetMs: 100)
        let config = PipelineConfig(sourceDelayMs: 200, sessionDelayMs: 300, segmentationEnabled: false)
        let result = LyricsPipeline.run(data, config: config)
        XCTAssertEqual(result.lines[0].startMs, 1600, "正=延后：+600")
        XCTAssertEqual(result.lines[0].syllables?.first?.startMs, 1600)

        let negative = PipelineConfig(sourceDelayMs: -800, segmentationEnabled: false)
        let back = LyricsPipeline.run(data, config: negative)
        XCTAssertEqual(back.lines[0].startMs, 300, "负=提前：100+100-800")
    }

    // MARK: - #6 简繁不影响 translation 语言（S6 §2.4-4）

    func testChineseNormalizeKeepsTranslationLanguage() {
        let line = LyricsLine(startMs: 0, endMs: 100, text: "軟體", translation: "Hello World")
        let result = TextStages.chineseNormalize(
            LyricsData(lines: [line]),
            preferSimplified: true
        )
        XCTAssertEqual(result.lines[0].text, "软体", "t2s 字符/词组级（軟體→软体；软件⇄軟體 属台化变体映射）")
        XCTAssertEqual(result.lines[0].translation, "Hello World", "translation 语言不受扰动")
    }

    // MARK: - #8 attachTranslation（D6 ±1500ms 就近）

    func testAttachTranslationNearestWithinWindow() {
        let main = LyricsData(lines: [LyricsLine(startMs: 0, endMs: 1000, text: "主行")])
        let secondary = LyricsData(lines: [
            LyricsLine(startMs: 1400, text: "远译"),
            LyricsLine(startMs: 100, text: "近译"),
            LyricsLine(startMs: 5000, text: "超窗译"),
        ])
        let merged = TranslationAligner.attachTranslation(main: main, secondary: secondary)
        XCTAssertEqual(merged.lines[0].translation, "近译", "±1500ms 窗口取最近")

        let noHit = TranslationAligner.attachTranslation(
            main: LyricsData(lines: [LyricsLine(startMs: 99000, text: "无译")]),
            secondary: secondary
        )
        XCTAssertNil(noHit.lines[0].translation)
    }

    // MARK: - #5/#7 显式标记与 romaji 占位（A12/D10）

    func testExplicitAndRomaji() {
        let line = LyricsLine(startMs: 0, endMs: 100, text: "Song\u{1F134}")
        let removed = TextStages.explicitNormalize(
            LyricsData(lines: [line]), policy: .remove
        )
        XCTAssertEqual(removed.lines[0].text, "Song")

        let kept = TextStages.explicitNormalize(
            LyricsData(lines: [LyricsLine(text: "Song\u{24BA}")]),
            policy: .keep
        )
        XCTAssertEqual(kept.lines[0].text, "Song\u{1F134}")

        let result = LyricsPipeline.run(LyricsData(lines: [LyricsLine(text: "行")]))
        XCTAssertNil(result.lines[0].pronunciation, "D10：romaji M1 恒 nil")
    }

    /// 背景人声识别（#9）。
    func testBackgroundVocalDetect() {
        let result = TextStages.backgroundVocalDetect(
            LyricsData(lines: [
                LyricsLine(text: "(背景歌词)"),
                LyricsLine(text: "（背景歌词）"),
                LyricsLine(text: "正常行"),
            ])
        )
        XCTAssertTrue(result.lines[0].isBackgroundVocal)
        XCTAssertTrue(result.lines[1].isBackgroundVocal)
        XCTAssertFalse(result.lines[2].isBackgroundVocal)
    }
}

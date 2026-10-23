import XCTest
@testable import LyricsCore

final class SplitterRegressionTests: XCTestCase {
    func testEnglishLinesNotSplitAndNoSameStart() {
        let lrc = """
        [00:10.00]That you shouldn't be, oh
        [00:20.00]You're the one that left me
        [00:30.00]now, nothin' to see at our feet
        """
        let parsed = LrcParser.parse(lrc)
        print("REPRO 解析后:")
        for l in parsed.lines {
            print("  [\(l.text)]")
        }
        let piped = LyricsPipeline.run(parsed)
        // D45 回归：英文行不切、无同 start 双段、行文本完整。
        XCTAssertEqual(piped.lines.map(\.text), [
            "That you shouldn't be, oh",
            "You're the one that left me",
            "now, nothin' to see at our feet",
        ])
        XCTAssertEqual(Set(piped.lines.compactMap(\.startMs)).count, piped.lines.count, "无同 start 双段")
    }

    func testCJKLongSentenceStillSplits() {
        let lrc = """
        [00:10.00]你就是我的风景云高风清不走下去停在这里视线里都是风景哦
        [00:20.00]尾行
        """
        let piped = LyricsPipeline.run(LrcParser.parse(lrc))
        XCTAssertGreaterThan(piped.lines.count, 1, "CJK 长句仍应切分")
        XCTAssertEqual(Set(piped.lines.compactMap(\.startMs)).count, piped.lines.count, "切分后 start 不重复")
        let total = piped.lines.map(\.text).joined()
        XCTAssertTrue(total.hasPrefix("你就是我的风景"), "内容不丢字")
        XCTAssertTrue(piped.lines.map(\.text).contains("尾行"))
    }

    func testLoneLongLineWithoutSpanNotSplit() {
        let piped = LyricsPipeline.run(LrcParser.parse("[00:10.00]你就是我的风景云高风清不走下去停在这里视线里都是风景哦"))
        XCTAssertEqual(piped.lines.count, 1, "无时间跨度不切（D45 口径：避免同 start 双段）")
    }
}

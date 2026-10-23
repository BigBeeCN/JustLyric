import XCTest
@testable import LyricsCore

/// 归一化与 LCS 测试（S2 §2.2 步骤 1/9；S6 §2.3-5 前置；S7 D5 词组级证据）。
final class NormalizationTests: XCTestCase {
    // MARK: - NormalizeName（步骤 1 顺序）

    /// 繁→简（t2s 词组级）+ lowercase：`周杰倫` 与 `周杰伦` 归一相等（S6 §2.3-5 前置）。
    func testTraditionalSimplifiedEquality() {
        XCTAssertEqual(NormalizeName("周杰倫"), NormalizeName("周杰伦"))
        XCTAssertEqual(NormalizeName("周杰倫"), "周杰伦")
    }

    /// 标点/大小写/空白映射（S2 §2.2 步骤 1 逐项）。
    func testPunctuationAndCaseMapping() {
        XCTAssertEqual(NormalizeName("  Foo，Bar  "), "foo,bar")
        XCTAssertEqual(NormalizeName("Don’t"), "don't")
        XCTAssertEqual(NormalizeName("Foo（Bar）"), "foo(bar)")
        XCTAssertEqual(NormalizeName("Foo[Bar]"), "foo(bar)")
    }

    // MARK: - 词组级证据（S7 D5：纯字符映射不可接受）

    /// 词组保护：`乾元` 不被字符级首候选误转为 `干元`。
    func testPhraseLevelProtection() {
        XCTAssertEqual(OpenCCChineseConverter.shared.toSimplified("乾元"), "乾元")
    }

    /// 词组级消歧：`壺裏乾坤` → `壶里乾坤`（字符级会误出 `壶里干坤`）。
    func testPhraseLevelDisambiguation() {
        XCTAssertEqual(OpenCCChineseConverter.shared.toSimplified("壺裏乾坤"), "壶里乾坤")
        XCTAssertEqual(OpenCCChineseConverter.shared.toSimplified("乾乾淨淨"), "干干净净")
    }

    /// s2twp 语义（D5）：`软件` → `軟體`（词组级台湾用词）。
    func testToTraditionalTaiwan() {
        XCTAssertEqual(OpenCCChineseConverter.shared.toTraditional("软件", region: .tw), "軟體")
    }

    /// s2twp vs s2hk 变体区分（D5）：`里` tw→`裡`、hk→`裏`。
    func testToTraditionalRegionDifference() {
        XCTAssertEqual(OpenCCChineseConverter.shared.toTraditional("里", region: .tw), "裡")
        XCTAssertEqual(OpenCCChineseConverter.shared.toTraditional("里", region: .hk), "裏")
    }

    /// s2hk 词组级（HKPhrases）：`丹尼·博伊尔` → `丹尼·波爾`。
    func testToTraditionalHongKong() {
        XCTAssertEqual(
            OpenCCChineseConverter.shared.toTraditional("丹尼·博伊尔", region: .hk),
            "丹尼·波爾"
        )
    }

    // MARK: - ComputeTextSame（步骤 9，LCS 阶梯前置）

    /// LCS 相似度基本档。
    func testLCSSimilarity() {
        XCTAssertEqual(ComputeTextSame("abcd", "abcd", isCase: true), 100)
        XCTAssertEqual(ComputeTextSame("abcd", "abxd", isCase: true), 75)
        XCTAssertEqual(ComputeTextSame("a", "ab", isCase: true), 50)
    }

    /// 保留 2 位小数（S2 §2.2 步骤 9）。
    func testRoundingToTwoDecimals() {
        XCTAssertEqual(ComputeTextSame("abc", "abd", isCase: true), 66.67, accuracy: 0.001)
    }

    /// isCase 语义：true 区分大小写，false 先小写化。
    func testCaseSensitivity() {
        XCTAssertEqual(ComputeTextSame("ABC", "abc", isCase: true), 0)
        XCTAssertEqual(ComputeTextSame("ABC", "abc", isCase: false), 100)
    }

    /// 空串保护。
    func testEmptyInput() {
        XCTAssertEqual(ComputeTextSame("", "abc", isCase: true), 0)
    }
}

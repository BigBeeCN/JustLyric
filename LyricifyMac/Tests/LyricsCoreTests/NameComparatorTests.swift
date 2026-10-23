import XCTest
@testable import LyricsCore

/// CompareName/CompareArtist/CompareDuration 测试（S2 §2.2–2.4；S6 §2.3-1/-2/-3/-5）。
final class NameComparatorTests: XCTestCase {
    // MARK: - CompareName（S6 §2.3-2）

    /// Perfect 与繁简归一（S6 §2.3-5）。
    func testPerfect() {
        XCTAssertEqual(CompareName("Hello", "hello"), .perfect)
        XCTAssertEqual(CompareName("周杰倫", "周杰伦"), .perfect, "繁→简词组级归一")
    }

    /// D2：acoustic version 归一后相等 → VeryHigh。
    func testAcousticVeryHigh() {
        XCTAssertEqual(CompareName("Song (Acoustic Version)", "Song (Acoustic)"), .veryHigh)
    }

    /// D24 钉死回归：T(s) 字面移植后 `"Song - Live"` vs `"Song (Live)"` 不等 →
    /// 不命中 VeryHigh，经 LCS 9/11≈81.8% → High。
    /// > Warning: 本用例防止未来被“顺手修正”（D24 原则：匹配引擎以字面移植为准）。
    func testDashToParenPinnedRegression_D24() {
        XCTAssertEqual(CompareName("Song - Live", "Song (Live)"), .high)
        XCTAssertNotEqual(CompareName("Song - Live", "Song (Live)"), .veryHigh)
    }

    /// DashToParen 命中：T 后相等（如右括号未闭合对）→ VeryHigh。
    func testDashToParenHit() {
        XCTAssertEqual(CompareName("Song - Live", "Song (Live"), .veryHigh)
    }

    /// SpecialCompare（deluxe/explicit/feat/with）→ VeryHigh。
    func testSpecialCompare() {
        XCTAssertEqual(CompareName("Album (Deluxe)", "Album"), .veryHigh)
        XCTAssertEqual(CompareName("Song (Explicit)", "Song"), .veryHigh)
        XCTAssertEqual(CompareName("Song (feat. Someone)", "Song"), .veryHigh)
        XCTAssertEqual(CompareName("Song (with Someone)", "Song"), .veryHigh)
        XCTAssertEqual(CompareName("Album (Bonus Track)", "Album"), .veryHigh)
    }

    /// DuoSpecial（feat|with + explicit 双向）→ High。
    func testDuoSpecial() {
        XCTAssertEqual(CompareName("Song (feat. X)", "Song (Explicit)"), .high)
    }

    /// D23：SingleSpecial 双边括号形态（`Song (feat A)` vs `Song (feat B)`）→ High。
    /// 同时为 SpecialCompare 双边均带→不命中 的负例断言。
    func testSingleSpecialBothSidesFeat() {
        let result = CompareName("Song (feat A)", "Song (feat B)")
        XCTAssertEqual(result, .high, "D23：双边基名相等 → High（此前会经 LCS 92% 误判 VeryHigh）")
        XCTAssertNotEqual(result, .veryHigh, "SpecialCompare 双边均带不命中（D23 负例）")
    }

    /// BracketsCompare → Medium。
    func testBracketsCompare() {
        XCTAssertEqual(CompareName("Song (Live)", "Song"), .medium)
    }

    /// 等长位置命中（D3）→ High。
    func testPositionalMatch() {
        XCTAssertEqual(CompareName("abcde", "abcdX"), .high)
    }

    /// LCS 阶梯边界（含精确边界值：严格大于）。
    func testLCSLadderBoundaries() {
        XCTAssertEqual(NameComparatorTier.tier(forTextSimilarity: 90), .high)
        XCTAssertEqual(NameComparatorTier.tier(forTextSimilarity: 90.01), .veryHigh)
        XCTAssertEqual(NameComparatorTier.tier(forTextSimilarity: 80), .medium)
        XCTAssertEqual(NameComparatorTier.tier(forTextSimilarity: 80.01), .high)
        XCTAssertEqual(NameComparatorTier.tier(forTextSimilarity: 68), .low)
        XCTAssertEqual(NameComparatorTier.tier(forTextSimilarity: 68.01), .medium)
        XCTAssertEqual(NameComparatorTier.tier(forTextSimilarity: 55), .noMatch)
        XCTAssertEqual(NameComparatorTier.tier(forTextSimilarity: 55.01), .low)
    }

    /// 空输入 → nil。
    func testEmptyReturnsNil() {
        XCTAssertNil(CompareName("", "abc"))
        XCTAssertNil(CompareName("abc", ""))
    }

    // MARK: - CompareDuration（S6 §2.3-1；P5 例 3）

    /// 时长边界档位。
    func testDurationBoundaries() {
        XCTAssertEqual(CompareDuration(1000, 1000), .perfect) // diff=0
        XCTAssertEqual(CompareDuration(1000, 1299), .veryHigh) // 299
        XCTAssertEqual(CompareDuration(1000, 1300), .high) // 300
        XCTAssertEqual(CompareDuration(1000, 1699), .high) // 699
        XCTAssertEqual(CompareDuration(1000, 1700), .medium) // 700
        XCTAssertEqual(CompareDuration(1000, 2499), .medium) // 1499
        XCTAssertEqual(CompareDuration(1000, 2500), .low) // 1500
        XCTAssertEqual(CompareDuration(1000, 4499), .low) // 3499
        XCTAssertEqual(CompareDuration(1000, 4500), .noMatch) // 3500
        XCTAssertNil(CompareDuration(nil, 1000))
        XCTAssertNil(CompareDuration(0, 1000))
    }

    // MARK: - CompareArtist（S6 §2.3-3；P5 例 4）

    /// P5 例 4a：规则 3 → High。
    func testArtistRule3() {
        XCTAssertEqual(CompareArtist(["周杰伦"], ["周杰伦", "费玉清"]), .high)
    }

    /// P5 例 4b：规则 4 不适用（B[0] 非"群星"）→ 规则 2 → VeryHigh。
    func testArtistRule2Fallback() {
        let a = ["a", "b", "c", "d", "e", "f", "g", "h"]
        let b = a + ["群星"]
        XCTAssertEqual(CompareArtist(a, b), .veryHigh)
    }

    /// 规则 1：Perfect。
    func testArtistRule1() {
        XCTAssertEqual(CompareArtist(["x", "y"], ["x", "y"]), .perfect)
    }

    /// 规则 4：B[0] 含"群星" → VeryHigh。
    func testArtistRule4() {
        XCTAssertEqual(CompareArtist(["a", "b", "c", "d", "e", "f"], ["群星"]), .veryHigh)
    }

    /// 规则 5 → High。
    func testArtistRule5() {
        let a = ["a", "b", "c", "d", "e", "f", "g", "h"]
        var b = a
        b.removeLast(2)
        b.append(contentsOf: ["z1", "z2"])
        XCTAssertEqual(CompareArtist(a, b), .high) // n=6, 6/8=0.75 > 0.66
    }

    /// 规则 6/7：前缀包含 High / 子串 Medium。
    func testArtistRule6And7() {
        XCTAssertEqual(CompareArtist(["abcd"], ["ab", "x"]), .high)
        XCTAssertEqual(CompareArtist(["abcd"], ["bc", "x"]), .medium)
    }

    /// 规则 8：Medium。
    func testArtistRule8() {
        XCTAssertEqual(CompareArtist(["a"], ["b", "c", "a"]), .medium)
    }

    /// 规则 9：Low / NoMatch。
    func testArtistRule9() {
        XCTAssertEqual(CompareArtist(["a", "b", "c", "d"], ["a", "b", "e", "f"]), .low)
        XCTAssertEqual(CompareArtist(["a", "b", "c", "d"], ["e", "f", "g", "h"]), .noMatch)
    }

    /// 繁简归一命中（S6 §2.3-5）。
    func testArtistTraditionalNormalized() {
        XCTAssertEqual(CompareArtist(["周杰倫"], ["周杰伦", "费玉清"]), .high)
    }
}

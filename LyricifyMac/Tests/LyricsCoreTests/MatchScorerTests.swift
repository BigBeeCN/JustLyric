import XCTest
@testable import LyricsCore

/// 合成打分测试（S2 §2.5；S6 §2.3-4；P5 金标准例 1/2）。
final class MatchScorerTests: XCTestCase {
    /// P5 例 1：精确期望值（容差 1e-6）→ VeryHigh。
    func testGoldenExample1() {
        let input = MatchScorer.MatchInput(
            name: .high, // 5
            artist: .perfect, // 7
            album: .veryHigh, // 6 × 0.4
            albumArtist: nil,
            duration: .medium // 4
        )
        // score_raw = 5 + 7 + 2.4 + 0 + 4 = 18.4；base = 14 + 2.8 + 7 = 23.8
        XCTAssertEqual(MatchScorer.score(input), 19.48235294117647, accuracy: 1e-6)
        XCTAssertEqual(MatchScorer.tier(for: MatchScorer.score(input)), .veryHigh)
    }

    /// P5 例 2：阈值边界严格大于。
    func testGoldenExample2Boundaries() {
        XCTAssertEqual(MatchScorer.tier(for: 19.0), .high)
        XCTAssertEqual(MatchScorer.tier(for: 19.000001), .veryHigh)
        XCTAssertEqual(MatchScorer.tier(for: 21.0), .veryHigh)
        XCTAssertEqual(MatchScorer.tier(for: 21.000001), .perfect)
    }

    /// S6 §2.3-4 组 2：全满分。
    func testAllPerfect() {
        let input = MatchScorer.MatchInput(
            name: .perfect,
            artist: .perfect,
            album: .perfect,
            albumArtist: .perfect,
            duration: .perfect
        )
        // raw = 7 + 7 + 2.8 + 1.4 + 7 = 25.2；base = 14 + 2.8 + 1.4 + 7 = 25.2 → 25.2
        XCTAssertEqual(MatchScorer.score(input), 25.2, accuracy: 1e-6)
        XCTAssertEqual(MatchScorer.tier(for: MatchScorer.score(input)), .perfect)
    }

    /// S6 §2.3-4 组 3：单维度（base 不加其他权重）。
    func testSingleDimension() {
        let input = MatchScorer.MatchInput(name: .medium)
        // raw = 4；base = 14 → 4 × 25.2 / 14 = 7.2
        XCTAssertEqual(MatchScorer.score(input), 7.2, accuracy: 1e-6)
        XCTAssertEqual(MatchScorer.tier(for: MatchScorer.score(input)), .veryLow)
    }

    /// S6 §2.3-4 组 4：两维度。
    func testTwoDimensions() {
        let input = MatchScorer.MatchInput(name: .high, duration: .low)
        // raw = 5 + 2 = 7；base = 14 + 7 = 21 → 7 × 25.2 / 21 = 8.4
        XCTAssertEqual(MatchScorer.score(input), 8.4, accuracy: 1e-6)
        XCTAssertEqual(MatchScorer.tier(for: MatchScorer.score(input)), .low)
    }

    /// S6 §2.3-4 组 5：null 维度不加权（albumArtist 权重）。
    func testAlbumArtistWeight() {
        let input = MatchScorer.MatchInput(name: .perfect, albumArtist: .perfect)
        // raw = 7 + 1.4 = 8.4；base = 14 + 1.4 = 15.4 → 8.4 × 25.2 / 15.4 = 13.745454…
        XCTAssertEqual(MatchScorer.score(input), 13.745454545454546, accuracy: 1e-6)
        XCTAssertEqual(MatchScorer.tier(for: MatchScorer.score(input)), .medium)
    }

    /// 多候选排序：档位↓ → 源优先级 → |offset| → 逐字能力。
    func testCandidateRanking() {
        let candidates = [
            MatchCandidate(score: 10, sourcePriority: 1, offsetMs: 100, supportsSyllable: true),
            MatchCandidate(score: 20, sourcePriority: 3, offsetMs: 0, supportsSyllable: false),
            MatchCandidate(score: 20, sourcePriority: 1, offsetMs: 200, supportsSyllable: true),
            MatchCandidate(score: 20, sourcePriority: 1, offsetMs: 50, supportsSyllable: false),
        ]
        let ranked = CandidateRanker.rank(candidates)
        XCTAssertEqual(ranked.map(\.score), [20, 20, 20, 10])
        XCTAssertEqual(ranked.map(\.offsetMs), [50, 200, 0, 100])
    }
}

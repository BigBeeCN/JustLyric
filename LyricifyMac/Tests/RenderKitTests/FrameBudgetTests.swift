import LyricsCore
import XCTest
@testable import RenderKit

/// 帧预算基准（S4 §6 / S6 §4：A4/A5 自动化——单帧 CPU <8ms 预算）。
final class FrameBudgetTests: XCTestCase {
    private final class StubClock: TimelineProviding {
        func elapsed(now: TimeInterval) -> Int {
            Int(now * 1000)
        }
    }

    /// 逐帧 tick 平均耗时（填充域只动 mask，D30 #1）。
    func testFillTickBudget() {
        let line = LyricsLine(
            startMs: 0,
            endMs: 240_000,
            text: String(repeating: "词", count: 40),
            syllables: (0 ..< 40).map {
                Syllable(text: "词", startMs: $0 * 6000, durationMs: 6000)
            }
        )
        let view = KaraokeTextView(line: line, clock: StubClock())
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 60)

        let iterations = 500
        var totalMs = 0.0
        for step in 0 ..< iterations {
            let start = CFAbsoluteTimeGetCurrent()
            view.tick(now: Double(step) * 0.016)
            totalMs += (CFAbsoluteTimeGetCurrent() - start) * 1000
        }
        let averageMs = totalMs / Double(iterations)
        print(String(format: "fill tick 平均 %.4f ms/帧（预算 8ms）", averageMs))
        XCTAssertLessThan(averageMs, 8.0, "S4 §6 单帧 CPU 预算")
        XCTAssertEqual(view.relayoutCount, 1, "帧内零重排（D30 #1）")
    }
}

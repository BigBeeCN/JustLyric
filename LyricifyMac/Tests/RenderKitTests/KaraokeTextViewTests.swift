import LyricsCore
import XCTest
@testable import RenderKit

/// KaraokeTextView 核心测试（S4 §2.2；S7 D30 #1/#5）。
final class KaraokeTextViewTests: XCTestCase {
    /// 桩时钟（D30 #5：组件禁止直读系统时钟，时间由外部供给）。
    private final class StubClock: TimelineProviding {
        func elapsed(now: TimeInterval) -> Int {
            Int(now * 1000)
        }
    }

    private func makeLine() -> LyricsLine {
        LyricsLine(
            startMs: 0,
            endMs: 2000,
            text: "词一词二",
            syllables: [
                Syllable(text: "词一", startMs: 0, durationMs: 1000),
                Syllable(text: "词二", startMs: 1000, durationMs: 1000),
            ]
        )
    }

    /// D30 #1：逐帧只动 mask（relayoutCount 不变）且边界单调（S6 §4）。
    func testTickUpdatesMaskOnlyAndMonotonic() {
        let view = KaraokeTextView(line: makeLine(), clock: StubClock())
        view.frame = NSRect(x: 0, y: 0, width: 200, height: 40)

        var previous: CGFloat = -1
        for step in 0 ... 20 {
            let now = Double(step) / 10
            view.tick(now: now)
            XCTAssertGreaterThanOrEqual(view.lastMaskWidth, previous, "now=\(now)")
            previous = view.lastMaskWidth
        }
        XCTAssertEqual(view.relayoutCount, 1, "D30 #1：逐帧不重排文本")
        XCTAssertGreaterThan(view.lastMaskWidth, 0)
    }

    /// D30 #5：同一时钟读数 → 同一边界（确定性）。
    func testClockInjectionDeterminism() {
        let first = KaraokeTextView(line: makeLine(), clock: StubClock())
        let second = KaraokeTextView(line: makeLine(), clock: StubClock())
        first.frame = NSRect(x: 0, y: 0, width: 200, height: 40)
        second.frame = NSRect(x: 0, y: 0, width: 200, height: 40)
        first.tick(now: 1.0)
        second.tick(now: 1.0)
        XCTAssertEqual(first.lastMaskWidth, second.lastMaskWidth)
    }

    /// updateLine 是唯一重排入口。
    func testUpdateLineRelayoutsOnce() {
        let view = KaraokeTextView(line: makeLine(), clock: StubClock())
        XCTAssertEqual(view.relayoutCount, 1)
        view.updateLine(makeLine())
        XCTAssertEqual(view.relayoutCount, 2)
    }
}

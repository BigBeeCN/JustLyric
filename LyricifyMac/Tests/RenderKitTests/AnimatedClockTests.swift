import LyricsCore
import XCTest
@testable import RenderKit

/// AnimatedClockView 测试（S4 §1；D30 #5 时钟注入）。
final class AnimatedClockTests: XCTestCase {
    private final class StubClock: TimelineProviding {
        let ms: Int
        init(ms: Int) {
            self.ms = ms
        }

        func elapsed(now: TimeInterval) -> Int {
            ms
        }
    }

    /// mm:ss 显示 + 翻牌变化 + ReduceMotion 直切。
    func testClockDisplay() {
        let clock = StubClock(ms: 125_000) // 2:05
        let view = AnimatedClockView(clock: clock)
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 20)
        view.tick(now: 0)
        XCTAssertEqual(view.currentText, "02:05")
        view.tick(now: 0)
        XCTAssertEqual(view.currentText, "02:05", "无变化不重绘")
    }
}

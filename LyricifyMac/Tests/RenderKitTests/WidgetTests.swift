import AppKit
import XCTest
@testable import RenderKit

/// 组件组测试（S4 §1）。
final class WidgetTests: XCTestCase {
    /// 自适应字号：长文本缩、短文本保基准。
    func testAdaptiveFitting() {
        let long = String(repeating: "超宽文本", count: 20)
        let fitted = AdaptiveTextFitting.fittedFontSize(
            text: long, baseFont: SnapshotBaseline.font, width: 100
        )
        XCTAssertLessThan(fitted, SnapshotBaseline.font.pointSize)

        let fittedShort = AdaptiveTextFitting.fittedFontSize(
            text: "短", baseFont: SnapshotBaseline.font, width: 300
        )
        XCTAssertEqual(fittedShort, SnapshotBaseline.font.pointSize, accuracy: 0.001)

        let floored = AdaptiveTextFitting.fittedFontSize(
            text: long, baseFont: SnapshotBaseline.font, width: 1, minScale: 0.5
        )
        XCTAssertGreaterThanOrEqual(floored, SnapshotBaseline.font.pointSize * 0.5)
    }

    /// 对唱双行布局：两槽上下排布。
    func testDuetLayout() {
        let first = NSView()
        let second = NSView()
        let duet = DuetLayoutView(firstLine: first, secondLine: second)
        duet.frame = NSRect(x: 0, y: 0, width: 300, height: 100)
        duet.layoutSubtreeIfNeeded()
        XCTAssertEqual(duet.slots.first, first)
        XCTAssertEqual(duet.slots.second, second)
        XCTAssertGreaterThan(first.frame.minY, second.frame.maxY - 1, "第一行在上")
    }

    /// 跑马灯：超宽滚动、ReduceMotion 静态。
    func testMarquee() {
        let marquee = MarqueeText()
        marquee.frame = NSRect(x: 0, y: 0, width: 100, height: 30)
        marquee.setText("这是一段非常长的跑马灯文本内容", speedPtsPerSecond: 60, reduceMotion: false)
        let keys = marquee.layer?.sublayers?.first?.animationKeys() ?? []
        XCTAssertTrue(keys.contains("marquee"))

        marquee.setText("这是一段非常长的跑马灯文本内容", reduceMotion: true)
        let staticKeys = marquee.layer?.sublayers?.first?.animationKeys() ?? []
        XCTAssertFalse(staticKeys.contains("marquee"), "ReduceMotion 不滚动")
    }

    /// 呼吸点：ReduceMotion 静态（无 opacity 动画）。
    func testBreathingDots() {
        let animated = BreathingDotsView()
        animated.frame = NSRect(x: 0, y: 0, width: 100, height: 20)
        animated.layoutSubtreeIfNeeded()
        let hasBreath = animated.layer?.sublayers?.contains {
            $0.animation(forKey: "opacity") != nil
        } ?? false
        XCTAssertTrue(hasBreath)

        let reduced = BreathingDotsView(reduceMotion: true)
        let hasStatic = reduced.layer?.sublayers?.contains {
            $0.animation(forKey: "opacity") != nil
        } ?? false
        XCTAssertFalse(hasStatic, "ReduceMotion 静态点")
    }
}

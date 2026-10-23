import XCTest
@testable import RenderKit

/// 行过渡计划测试（S4 §3 七行为；S7 D30 #6 spring 域）。
final class LineTransitionTests: XCTestCase {
    /// 七行为正常态：滚动位移/浮起/透明度/缩放/回弹/曲线。
    func testPlanBehaviors() {
        let config = LineAnimationConfig()
        let plan = LineTransitionPlanner.plan(config: config, lineHeight: 40)

        XCTAssertEqual(plan.current.opacity, 1, "当前行全亮")
        XCTAssertEqual(plan.previous.opacity, 0.55, accuracy: 0.001, "未唱行 unplayedOpacity")
        XCTAssertEqual(plan.preplay.opacity, 0.8, accuracy: 0.001, "预下行")
        XCTAssertEqual(plan.current.scale, 1.08, accuracy: 0.001, "playingZoom")
        XCTAssertEqual(plan.previous.scale, 1)
        XCTAssertEqual(plan.current.liftY, 0, "浮起默认关")
        XCTAssertEqual(plan.previous.offsetY, -44, accuracy: 0.001, "滚动 -lineHeight + 回弹 -4pt")
        XCTAssertEqual(plan.preplay.offsetY, 40, accuracy: 0.001)
        XCTAssertEqual(plan.pullingDelayMs, 0)
        XCTAssertEqual(
            plan.curve,
            .spring(response: 0.45, damping: 0.85),
            "D30 #6：滚动 spring 域"
        )
    }

    /// 浮起开启 + 中文缓动曲线。
    func testFloatAndChineseEasing() {
        var config = LineAnimationConfig()
        config.floatEnabled = true
        config.chineseRollingEasing = true
        let plan = LineTransitionPlanner.plan(config: config, lineHeight: 40)
        XCTAssertEqual(plan.current.liftY, -2, accuracy: 0.001, "floatHeight=2pt")
        XCTAssertEqual(
            plan.curve,
            .cubicBezier(CubicBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1)),
            "karaoke_chinese_easing → cubic-bezier(0.25,0.1,0.25,1)"
        )
    }

    /// ReduceMotion：位移/缩放退化为透明度过渡（S4 §3）。
    func testReduceMotionDegradesToOpacityOnly() {
        var config = LineAnimationConfig()
        config.reduceMotion = true
        config.floatEnabled = true
        let plan = LineTransitionPlanner.plan(config: config, lineHeight: 40)

        XCTAssertEqual(plan.curve, .none)
        XCTAssertEqual(plan.previous.offsetY, 0)
        XCTAssertEqual(plan.preplay.offsetY, 0)
        XCTAssertEqual(plan.current.liftY, 0)
        XCTAssertEqual(plan.current.scale, 1)
        XCTAssertEqual(plan.previous.opacity, 0.55, accuracy: 0.001, "透明度过渡保留")
        XCTAssertEqual(plan.backgroundVocalEnterOffset, .zero)
    }

    /// 背景人声进入方向（七行为之 7）。
    func testBackgroundVocalDirection() {
        var config = LineAnimationConfig()
        config.backgroundVocalsEnteringDirection = .right
        let plan = LineTransitionPlanner.plan(config: config, lineHeight: 40)
        XCTAssertEqual(plan.backgroundVocalEnterOffset.x, 10, accuracy: 0.001)
        XCTAssertEqual(plan.backgroundVocalEnterOffset.y, 0)
    }

    /// 三次贝塞尔求值（端点/单调）。
    func testCubicBezier() {
        let curve = CubicBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1)
        XCTAssertEqual(curve.value(at: 0), 0, accuracy: 0.001)
        XCTAssertEqual(curve.value(at: 1), 1, accuracy: 0.001)
        var previous = -1.0
        for x in stride(from: 0.0, through: 1.0, by: 0.05) {
            let y = curve.value(at: x)
            XCTAssertGreaterThanOrEqual(y, previous, "单调 x=\(x)")
            previous = y
        }
    }

    /// spring → CA 参数映射（实现级公式断言）。
    func testSpringTimingMapper() {
        let parameters = SpringTimingMapper.caParameters(response: 0.45, damping: 0.85)
        XCTAssertEqual(parameters.mass, 1)
        XCTAssertEqual(parameters.stiffness, pow(2 * Double.pi / 0.45, 2), accuracy: 0.001)
        XCTAssertEqual(
            parameters.dampingCA,
            2 * 0.85 * sqrt(pow(2 * Double.pi / 0.45, 2)),
            accuracy: 0.001
        )
    }
}

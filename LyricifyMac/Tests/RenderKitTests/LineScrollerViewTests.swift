import AppKit
import XCTest
@testable import RenderKit

/// LineScrollerView CA 应用测试（S4 §3 ReduceMotion；S7 D30 #6 域分离）。
final class LineScrollerViewTests: XCTestCase {
    private func makeView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 40))
        view.wantsLayer = true
        return view
    }

    /// 正常态：spring 位移/缩放动画挂 CA 层。
    func testSpringAnimationsApplied() {
        let scroller = LineScrollerView()
        var config = LineAnimationConfig()
        config.floatEnabled = true
        let plan = LineTransitionPlanner.plan(config: config, lineHeight: 40)

        let previous = makeView()
        let current = makeView()
        let preplay = makeView()
        scroller.apply(plan: plan, previous: previous, current: current, preplay: preplay)

        let keys = current.layer?.animationKeys() ?? []
        XCTAssertTrue(keys.contains("position.y"), "spring 位移动画")
        XCTAssertTrue(keys.contains("transform.scale"), "zoom 动画")
    }

    /// S6 §4：ReduceMotion 下无位移动画（仅透明度）。
    func testReduceMotionHasNoDisplacementAnimations() {
        let scroller = LineScrollerView()
        var config = LineAnimationConfig()
        config.reduceMotion = true
        let plan = LineTransitionPlanner.plan(config: config, lineHeight: 40)

        let previous = makeView()
        let current = makeView()
        let preplay = makeView()
        scroller.apply(plan: plan, previous: previous, current: current, preplay: preplay)

        for view in [previous, current, preplay] {
            let keys = view.layer?.animationKeys() ?? []
            XCTAssertFalse(keys.contains("position.y"), "ReduceMotion 无位移动画")
            XCTAssertFalse(keys.contains("transform.scale"), "ReduceMotion 无缩放动画")
            XCTAssertTrue(keys.contains("opacity"), "退化为透明度过渡")
        }
    }

    /// 中文缓动：贝塞尔曲线挂 position 动画（D30 #6 时间基准独立）。
    func testChineseEasingAnimation() {
        let scroller = LineScrollerView()
        var config = LineAnimationConfig()
        config.chineseRollingEasing = true
        let plan = LineTransitionPlanner.plan(config: config, lineHeight: 40)
        let view = makeView()
        scroller.apply(plan: plan, previous: makeView(), current: view, preplay: makeView())
        let keys = view.layer?.animationKeys() ?? []
        XCTAssertTrue(keys.contains("position.y"))
        XCTAssertNil(view.layer?.animation(forKey: "transform.scale"), "无 zoom 需求则不挂")
    }
}

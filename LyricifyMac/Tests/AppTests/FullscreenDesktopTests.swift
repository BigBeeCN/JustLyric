import XCTest
@testable import App

/// 全屏 + 桌面窗测试（S4 §5、S5 §3；D35/D39）。
final class FullscreenDesktopTests: XCTestCase {
    // MARK: - M4-03 全屏（D35）

    /// D35 默认：进度条底部细条、缩放 1.0、AdaptiveText 0.5× 下限、防休眠。
    func testFullscreenDefaults() {
        let config = FullscreenConfig()
        XCTAssertEqual(config.progressBarMode, .bottomThin)
        XCTAssertEqual(config.zoomingLevel, 1.0, accuracy: 0.001)
        XCTAssertEqual(config.adaptiveMinScale, 0.5, accuracy: 0.001)
        XCTAssertTrue(config.preventSleep)
    }

    /// AdaptiveText 0.5× 下限生效。
    func testAdaptiveFloor() {
        let window = FullscreenWindow()
        let long = String(repeating: "超宽文本", count: 40)
        let size = window.fittedFontSize(text: long, width: 10)
        XCTAssertGreaterThanOrEqual(size, 8.5, "不低于 17pt×0.5（下限内）")
    }

    /// 防休眠启停不崩。
    func testSleepPrevention() {
        let prevention = SleepPrevention()
        _ = prevention.start()
        prevention.stop()
    }

    // MARK: - M4-04 桌面窗（S5 §3）

    /// 锁定→穿透；锁定禁入编辑。
    func testLockBehavior() {
        var behavior = PanelBehavior(isLocked: true)
        XCTAssertTrue(behavior.ignoresMouse, "锁定后点击穿透")
        behavior.handleDoubleClick()
        XCTAssertFalse(behavior.isEditing, "锁定时禁入编辑")

        behavior = PanelBehavior()
        XCTAssertFalse(behavior.ignoresMouse)
        behavior.handleDoubleClick()
        XCTAssertTrue(behavior.isEditing)
        XCTAssertTrue(behavior.showsEditBorder)
    }

    /// 自动隐藏：停止 5s（编辑态/关开关不隐藏）。
    func testAutoHide() {
        var behavior = PanelBehavior()
        XCTAssertFalse(behavior.shouldAutoHide(playbackStoppedAt: 0, now: 4.9))
        XCTAssertTrue(behavior.shouldAutoHide(playbackStoppedAt: 0, now: 5.0), "S5 §3 停止 5s")

        behavior.isEditing = true
        XCTAssertFalse(behavior.shouldAutoHide(playbackStoppedAt: 0, now: 10), "编辑态不隐藏")

        behavior = PanelBehavior(autoHide: false)
        XCTAssertFalse(behavior.shouldAutoHide(playbackStoppedAt: 0, now: 10))
    }

    /// 全屏隐藏（`fullscreen_hide`）。
    func testFullscreenHide() {
        XCTAssertTrue(PanelBehavior().shouldHideOnFullscreen(isAnyAppFullscreen: true))
        XCTAssertFalse(PanelBehavior().shouldHideOnFullscreen(isAnyAppFullscreen: false))
        XCTAssertFalse(
            PanelBehavior(fullscreenHide: false).shouldHideOnFullscreen(isAnyAppFullscreen: true)
        )
    }

    /// 边缘吸附（S5 §3）。
    func testEdgeSnap() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let size = CGSize(width: 200, height: 50)
        let snapped = EdgeSnap.snap(
            proposedOrigin: CGPoint(x: 10, y: 760),
            frameSize: size,
            screenFrame: screen
        )
        XCTAssertEqual(snapped.x, 0, accuracy: 0.001)
        XCTAssertEqual(snapped.y, 750, accuracy: 0.001, "吸附顶/底缘")

        let free = EdgeSnap.snap(
            proposedOrigin: CGPoint(x: 300, y: 300),
            frameSize: size,
            screenFrame: screen
        )
        XCTAssertEqual(free.x, 300, accuracy: 0.001, "远离边缘不吸附")
    }

    /// 编辑态焦点行为（D39 提示 #1 描述件：编辑态可成为 key）。
    func testEditFocusBehavior() {
        let panel = DesktopPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 80))
        XCTAssertFalse(panel.canBecomeKey, "非编辑态不抢焦点（nonactivating）")
        panel.doubleClicked()
        XCTAssertTrue(panel.canBecomeKey, "编辑态转可激活")
        panel.doubleClicked()
        XCTAssertFalse(panel.canBecomeKey, "退出恢复 nonactivating")
    }
}

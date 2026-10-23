import XCTest
@testable import App

/// 菜单栏 + 灵动条测试（S4 §5；S7 D35 预钉）。
final class MenuBarIslandTests: XCTestCase {
    // MARK: - M4-01 菜单栏（D35）

    /// 内容=曲名-歌手（D35）。
    func testMenuContentFormat() {
        XCTAssertEqual(MenuBarMarquee.content(title: "曲", artist: "手"), "曲 - 手")
        XCTAssertEqual(MenuBarMarquee.content(title: "曲", artist: nil), "曲")
        XCTAssertEqual(MenuBarMarquee.content(title: nil, artist: "手"), "手")
        XCTAssertEqual(MenuBarMarquee.content(title: nil, artist: nil), "未在播放")
    }

    /// 跑马灯时序：30pt/s + 两端驻留 1.5s（D35）。
    func testMarqueeCycleMath() {
        XCTAssertEqual(MenuBarMarquee.scrollSpeedPtsPerSecond, 30, accuracy: 0.001)
        XCTAssertEqual(MenuBarMarquee.dwellSeconds, 1.5, accuracy: 0.001)
        // 300pt 文本 / 100pt 视口：travel 200pt → 6.667s 单程 → (6.667+1.5)*2
        let cycle = MenuBarMarquee.cycleSeconds(textWidth: 300, viewportWidth: 100)
        XCTAssertEqual(cycle, (200.0 / 30.0 + 1.5) * 2, accuracy: 0.001)
        // 不超宽不滚。
        XCTAssertEqual(MenuBarMarquee.cycleSeconds(textWidth: 80, viewportWidth: 100), 0)
    }

    /// 迷你面板 ESC 关闭（S4 §5）。
    func testMiniPanelESCClose() {
        let panel = MiniPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
        panel.cancelOperation(nil)
        XCTAssertTrue(panel.wasDismissedByESC)
    }

    // MARK: - M4-02 灵动条（D35）

    /// 布局常数：24/36/18/60%。
    func testIslandLayoutConstants() {
        XCTAssertEqual(IslandLayout.topMargin, 24, accuracy: 0.001)
        XCTAssertEqual(IslandLayout.height, 36, accuracy: 0.001)
        XCTAssertEqual(IslandLayout.cornerRadius, 18, accuracy: 0.001)
        XCTAssertEqual(IslandLayout.maxScreenWidthRatio, 0.6, accuracy: 0.001)

        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frame = IslandLayout.panelFrame(screenFrame: screen, contentWidth: 200)
        XCTAssertEqual(frame.midX, 500, accuracy: 0.001, "顶部居中")
        XCTAssertEqual(frame.origin.y, 24, accuracy: 0.001)
        XCTAssertEqual(frame.height, 36, accuracy: 0.001)

        let capped = IslandLayout.panelFrame(screenFrame: screen, contentWidth: 900)
        XCTAssertEqual(capped.width, 600, accuracy: 0.001, "≤屏 60%")

        let half = IslandLayout.halfHiddenFrame(frame)
        XCTAssertEqual(half.origin.y, frame.origin.y - 18, accuracy: 0.001, "半隐藏露出一半")
    }

    /// byland 状态机：悬停展开/退出防抖/边界。
    func testBylandStateMachine() {
        let machine = BylandStateMachine()
        XCTAssertEqual(machine.state, .halfHidden)

        machine.handle(.expand) // 幂等展开
        XCTAssertEqual(machine.state, .expanded)
        machine.handle(.expand)
        XCTAssertEqual(machine.state, .expanded)

        machine.handle(.hoverEntered)
        XCTAssertEqual(machine.state, .expanded)
        machine.handle(.collapse)
        XCTAssertEqual(machine.state, .expanded, "边界：悬停中不收起")

        machine.handle(.hoverExited)
        XCTAssertEqual(machine.state, .expanded, "退出后防抖 0.8s 未到")

        let expectation = expectation(description: "防抖后半隐藏")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(machine.state, .halfHidden)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        machine.handle(.snapRequested)
        XCTAssertEqual(machine.state, .halfHidden, "snap 强制回贴边")
    }
}

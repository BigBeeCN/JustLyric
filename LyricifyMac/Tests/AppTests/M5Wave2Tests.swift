import XCTest
@testable import App

/// M5 波次 2 测试（S4 §1/§5；D39/D46①）。
final class M5Wave2Tests: XCTestCase {
    /// D39 四缘吸附：top/bottom/left/right 几何 + 半隐藏露出比。
    func testFourEdgeDocking() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let top = IslandLayout.panelFrame(screenFrame: screen, contentWidth: 200)
        XCTAssertEqual(top.origin.y, 24, accuracy: 0.001)
        XCTAssertEqual(top.midX, 500, accuracy: 0.001)

        let bottom = IslandLayout.panelFrame(screenFrame: screen, contentWidth: 200, edge: .bottom)
        XCTAssertEqual(bottom.origin.y, 800 - 24 - 36, accuracy: 0.001)

        let left = IslandLayout.panelFrame(screenFrame: screen, contentWidth: 200, edge: .left)
        XCTAssertEqual(left.origin.x, 24, accuracy: 0.001)
        XCTAssertEqual(left.width, 36, accuracy: 0.001, "侧缘立式")

        let right = IslandLayout.panelFrame(screenFrame: screen, contentWidth: 200, edge: .right)
        XCTAssertEqual(right.origin.x, 1000 - 24 - 36, accuracy: 0.001)

        // 半隐藏露出比 1/2（D39 边界四条之一）。
        XCTAssertEqual(IslandLayout.halfHiddenFrame(top).origin.y, top.origin.y - 18, accuracy: 0.001)
        XCTAssertEqual(
            IslandLayout.halfHiddenFrame(bottom, edge: .bottom).origin.y,
            bottom.origin.y + 18,
            accuracy: 0.001
        )
        XCTAssertEqual(IslandLayout.halfHiddenFrame(left, edge: .left).origin.x, left.origin.x - 18, accuracy: 0.001)
        XCTAssertEqual(IslandLayout.halfHiddenFrame(right, edge: .right).origin.x, right.origin.x + 18, accuracy: 0.001)
    }

    /// 设置键位预留（D39）：`island.dock_edge` 默认 top、缺键回退。
    func testDockEdgeSettingKeyReserved() throws {
        let settings = SettingsFile()
        XCTAssertEqual(settings.island.dockEdge, "top")
        let decoded = try JSONDecoder().decode(SettingsFile.self, from: Data("{\"version\":1}".utf8))
        XCTAssertEqual(decoded.island.dockEdge, "top", "缺键回退组件默认")
    }

    /// 限定语逐字核对栏（D46①）：D39"四缘任意吸附"仅为 M5 增强，v1 顶缘语义不漂移。
    func testV1TopEdgeSemanticsUnchanged() {
        // D39：D35 #2"拖至左/右缘"措辞废止；默认调用仍为顶缘。
        let frame = IslandLayout.panelFrame(
            screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            contentWidth: 200
        )
        XCTAssertEqual(frame.origin.y, 24, accuracy: 0.001, "默认顶缘（限定语核对）")
    }
}

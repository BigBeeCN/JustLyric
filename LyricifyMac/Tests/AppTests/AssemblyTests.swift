import MediaSession
import XCTest
@testable import App

/// M4-10 组装测试（S5 §2/§3/§4）。
final class AssemblyTests: XCTestCase {
    /// 组装器启动：设置回读 + 引导推导 + 启动日志。
    func testCoordinatorStart() {
        let store = SettingsStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("assembly-\(UUID().uuidString).json")
        )
        let coordinator = AppCoordinator(settingsStore: store)
        let log = coordinator.start(mode: .full, automationDenied: false)
        XCTAssertTrue(log.contains("集成模式=full"))
        XCTAssertTrue(log.contains("无上传"), "S5 §4 零遥测")
        XCTAssertNil(coordinator.permissionPrompt.pending)
    }

    /// 权限引导推导（S3 §7）。
    func testPermissionPromptResolution() {
        let degraded = PermissionPrompt.resolve(mode: .directOnly, automationDenied: false)
        XCTAssertEqual(degraded.pending, .mediaRemoteDegraded)
        let denied = PermissionPrompt.resolve(mode: .full, automationDenied: true)
        XCTAssertEqual(denied.pending, .automation)
        XCTAssertEqual(denied.textKey(for: .automation), PermissionGuide.automationDeniedNoticeKey)
    }

    /// 显示面开关独立 + 记忆（S6 §5 手测项模块级）。
    func testWindowSurfaceMemory() {
        var manager = WindowManager()
        manager.setEnabled(.desktopLyrics, on: true)
        manager.setEnabled(.menuBar, on: true)
        manager.setEnabled(.desktopLyrics, on: false)
        XCTAssertEqual(manager.activeSurfaces, [.menuBar], "独立开关")
        XCTAssertEqual(manager.memory["desktopLyrics"], false, "记忆")

        let restored = WindowManager(memory: manager.memory)
        XCTAssertEqual(restored.enabled[.menuBar], true)
        XCTAssertEqual(restored.enabled[.desktopLyrics], false)
    }

    /// 单实例决策（S5 §2）。
    func testSingleInstanceDecision() {
        XCTAssertTrue(AppLifecycle.shouldYieldToExisting(bundleID: "x", running: 2))
        XCTAssertFalse(AppLifecycle.shouldYieldToExisting(bundleID: "x", running: 1))
    }
}

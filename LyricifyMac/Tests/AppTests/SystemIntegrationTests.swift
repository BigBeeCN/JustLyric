import XCTest
@testable import App

/// 系统集成测试（S5 §2；D35 热键默认不绑定）。
final class SystemIntegrationTests: XCTestCase {
    /// D35：默认不绑定。
    func testHotkeyDefaultsEmpty() {
        XCTAssertTrue(HotkeyManager.defaultBindings.isEmpty, "默认不绑定原则")
        let manager = HotkeyManager()
        XCTAssertTrue(manager.bindings.isEmpty)
    }

    /// 绑定去重冲突拒收。
    func testBindDeduplication() {
        let manager = HotkeyManager()
        let hotkey = Hotkey(keyCode: 0, modifiers: 256)
        XCTAssertTrue(manager.bind(action: "toggle", hotkey: hotkey))
        XCTAssertFalse(manager.bind(action: "other", hotkey: hotkey), "冲突拒收")
        manager.unbind(action: "toggle")
        XCTAssertTrue(manager.bindings.isEmpty)
    }

    /// 录制状态机：capture/冲突/取消。
    func testRecorderStateMachine() {
        let recorder = HotkeyRecorder()
        XCTAssertEqual(recorder.state, .idle)

        // 未录制时按键拒收。
        XCTAssertFalse(recorder.capture(keyCode: 0, modifiers: 256))
        XCTAssertEqual(recorder.lastRejection, "not-recording")

        recorder.start()
        XCTAssertEqual(recorder.state, .recording)
        // 规则 1：无修饰非功能键拒收（A15 待批规则）。
        XCTAssertFalse(recorder.capture(keyCode: 0, modifiers: 0))
        XCTAssertEqual(recorder.lastRejection, "modifier-required")
        // 功能键免修饰。
        XCTAssertTrue(recorder.capture(keyCode: 122, modifiers: 0), "F1 免修饰")
        XCTAssertEqual(recorder.captured?.keyCode, 122)
        XCTAssertEqual(recorder.state, .idle)

        // 规则 2：重复拒收。
        recorder.start()
        XCTAssertFalse(
            recorder.capture(keyCode: 0, modifiers: 256, existing: [Hotkey(keyCode: 0, modifiers: 256)]),
            "duplicate"
        )
        recorder.cancel()
        XCTAssertEqual(recorder.state, .idle)
    }

    /// 睡眠策略（prevent_sleep_fullscreen_only）。
    func testSleepPolicy() {
        let policy = SleepPolicy()
        XCTAssertTrue(policy.preventSleepFullscreenOnly)
        XCTAssertTrue(policy.shouldPreventSleep(isFullscreenActive: true, anyPlayback: true))
        XCTAssertFalse(policy.shouldPreventSleep(isFullscreenActive: false, anyPlayback: true))
        XCTAssertFalse(policy.shouldPreventSleep(isFullscreenActive: true, anyPlayback: false))

        let always = SleepPolicy(preventSleepFullscreenOnly: false)
        XCTAssertTrue(always.shouldPreventSleep(isFullscreenActive: false, anyPlayback: true))
    }
}

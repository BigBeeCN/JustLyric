import XCTest
@testable import App

/// M4-06/07/08 视图模型测试（S3 §4/§5、S5 §1.1）。
final class SettingsViewModelsTests: XCTestCase {
    /// D40：系统拒止清单命中 → "系统保留"；用户覆盖放行（默认禁止）。
    func testSystemReservedRejection() {
        let recorder = HotkeyRecorder()
        recorder.start()
        let cmdSpace = Hotkey(keyCode: 49, modifiers: 0x100)
        XCTAssertFalse(recorder.capture(keyCode: cmdSpace.keyCode, modifiers: cmdSpace.modifiers))
        XCTAssertEqual(recorder.lastRejection, SystemReservedHotkeys.rejectionReason)

        recorder.allowsSystemReservedOverride = true
        recorder.start()
        XCTAssertTrue(
            recorder.capture(keyCode: cmdSpace.keyCode, modifiers: cmdSpace.modifiers),
            "用户覆盖放行（D40 补充）"
        )
    }

    /// D40 A15-2：清单 = 点名最小集（不自行扩大——数量与成员断言）。
    func testReservedListIsMinimalSet() {
        XCTAssertEqual(SystemReservedHotkeys.reserved.count, 11, "D40 点名最小集，不得扩大")
        XCTAssertTrue(SystemReservedHotkeys.isReserved(Hotkey(keyCode: 48, modifiers: 0x100)))
        XCTAssertTrue(SystemReservedHotkeys.isReserved(Hotkey(keyCode: 125, modifiers: 0x1000)))
        XCTAssertFalse(SystemReservedHotkeys.isReserved(Hotkey(keyCode: 0, modifiers: 0x100)), "⌘A 不拒止")
    }

    /// M4-06：未知 app 询问流程 + 记忆。
    func testSessionViewModel() {
        var model = SessionSettingsViewModel()
        XCTAssertNil(model.decision(bundleID: "com.unknown.app", kind: .unknown), "需询问")
        XCTAssertEqual(model.decision(bundleID: "com.x", kind: .musicApp), true)

        model.remember(bundleID: "com.unknown.app", enabled: true)
        XCTAssertEqual(model.decision(bundleID: "com.unknown.app", kind: .unknown), true)
        XCTAssertEqual(model.entries["com.unknown.app"]?.kind, "unknown")
    }

    /// M4-07：蓝牙 +150ms 预填→确认写入（D29 #1）+ 跟拍测试器。
    func testLatencyCalibrator() {
        var calibrator = LatencyCalibrator()
        calibrator.loadSuggestion(isBluetooth: true)
        XCTAssertEqual(calibrator.pendingSuggestion, 150)
        XCTAssertTrue(calibrator.config.perDevice.isEmpty, "预填≠写入（D29 #1）")

        calibrator.confirmSuggestion(deviceUID: "bt-1")
        XCTAssertEqual(calibrator.config.perDevice["bt-1"]?.latencyMs, 150)
        XCTAssertNil(calibrator.pendingSuggestion)

        XCTAssertEqual(
            LatencyCalibrator.tapCalibrationOffset(tapOffsetsMs: [100, 200, 300]),
            200
        )
        XCTAssertNil(LatencyCalibrator.tapCalibrationOffset(tapOffsetsMs: []))
    }

    /// M4-08：SourcePreferences 桥接 + 目录校验。
    func testSourceSettingsViewModel() {
        var settings = SourcesSettings()
        settings.lyricsSourcesDisabled = ["apple_ttml"]
        settings.lyricsLatency = ["lrclib": 30]
        let model = SourceSettingsViewModel(settings: settings)
        let preferences = model.preferences(minMatch: .low)
        XCTAssertFalse(preferences.isEnabled(.appleTTML))
        XCTAssertEqual(preferences.lyricsLatencyBySource[.lrclib], 30)
        XCTAssertTrue(model.isValidDirectory("/tmp/lyrics"))
        XCTAssertFalse(model.isValidDirectory("   "))
    }
}

import XCTest
@testable import MediaSession

/// 延迟校准测试（S3 §5；S6 §3-4；S7 D29 #1）。
final class LatencyTests: XCTestCase {
    /// 桩探测器。
    private struct StubInspector: AudioDeviceInspecting {
        let uid: String?
        let bluetooth: Bool
        func defaultOutputDeviceUID() -> String? {
            uid
        }

        func isBluetoothOutput(uid: String?) -> Bool {
            bluetooth
        }
    }

    /// S6 §3-4：四层叠加求和（含缺失层与负值，D29 #1 正值=延后）。
    func testEffectiveOffsetStacking() {
        let config = LatencyConfig(
            globalMs: 100,
            perDevice: ["dev-1": DeviceLatency(latencyMs: 150, deviceType: .bluetooth)],
            perSource: ["lrclib": 30, "apple_ttml": -20],
            perApp: ["com.spotify.client": 50]
        )
        XCTAssertEqual(
            config.effectiveOffsetMs(
                currentOutputDeviceUID: "dev-1",
                hitSource: "lrclib",
                bundleID: "com.spotify.client"
            ),
            330
        )
        XCTAssertEqual(
            config.effectiveOffsetMs(
                currentOutputDeviceUID: "dev-2",
                hitSource: "apple_ttml",
                bundleID: "com.other"
            ),
            80,
            "缺失层计 0；负值参与求和"
        )
        XCTAssertEqual(
            config.effectiveOffsetMs(
                currentOutputDeviceUID: nil, hitSource: nil, bundleID: nil
            ),
            100
        )
        XCTAssertEqual(
            LatencyConfig(globalMs: -50).effectiveOffsetMs(
                currentOutputDeviceUID: nil, hitSource: nil, bundleID: nil
            ),
            -50,
            "求和可为负（D29 #1）"
        )
    }

    /// D29 #1：蓝牙 +150ms 仅 UI 预填，不自动生效。
    func testBluetoothSuggestionIsPrefillOnly() {
        let monitor = AudioDeviceMonitor(inspector: StubInspector(uid: "bt-1", bluetooth: true))
        XCTAssertTrue(monitor.isBluetoothOutput())
        XCTAssertEqual(monitor.latencySuggestion(), 150)

        var config = LatencyConfig()
        XCTAssertEqual(config.perDevice, [:], "预填不等于写入")
        // 用户确认后才写入。
        monitor.confirmSuggestion(into: &config)
        XCTAssertEqual(config.perDevice["bt-1"]?.latencyMs, 150)
        XCTAssertEqual(config.perDevice["bt-1"]?.deviceType, .bluetooth)
    }

    /// 非蓝牙无建议。
    func testNoSuggestionForWired() {
        let monitor = AudioDeviceMonitor(inspector: StubInspector(uid: "spk-1", bluetooth: false))
        XCTAssertNil(monitor.latencySuggestion())
    }
}

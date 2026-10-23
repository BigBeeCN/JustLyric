import XCTest
@testable import MediaSession

/// AdapterHost 测试（S7 D37 强制项）。
final class AdapterHostTests: XCTestCase {
    /// D37 #2：能力探测（存在→加载→探针应答）——无效路径即降级。
    func testProbeDegrade() async {
        let host = PerlAdapterHost(
            dylibPath: "/nonexistent/no-such.dylib",
            hostScriptPath: "Sources/MediaSession/MediaRemoteAdapter/adapter-host.pl"
        )
        let ok = await host.probe()
        XCTAssertFalse(ok, "宿主不可用 → 降级（D37 #3）")
        XCTAssertNil(host.latestState)
    }

    /// D37 #4：崩溃自动重启 ≤1 次/分钟防抖。
    func testRestartDebounce() {
        XCTAssertEqual(PerlAdapterHost.restartDebounceSeconds, 60)
    }

    /// JSON 行解析（D37 #4 流式载荷）。
    func testPayloadParsing() {
        let payload = AdapterPayload.parse(
            "{\"type\":\"state\",\"title\":\"T\",\"durationMs\":1000}"
        )
        XCTAssertEqual(payload?["title"] as? String, "T")
        XCTAssertNil(AdapterPayload.parse("not json"))
        XCTAssertNil(AdapterPayload.parse("{\"type\":\"probe\"}")?["title"])
    }

    /// 直连 > 窗口标题 降级链次序（D37 #3）。
    func testFallbackPriority() {
        XCTAssertEqual(DirectConnectionPriority.rank(forMediaSourceID: "mediaremote"), 1)
        XCTAssertEqual(DirectConnectionPriority.rank(forMediaSourceID: "music"), 0)
        XCTAssertEqual(DirectConnectionPriority.rank(forMediaSourceID: "window-title"), 2)
    }
}

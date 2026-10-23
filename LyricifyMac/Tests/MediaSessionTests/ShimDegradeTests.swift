import XCTest
@testable import MediaSession

/// MediaRemoteShim 降级演练（S3 §7；S7 D25 #3）。
final class ShimDegradeTests: XCTestCase {
    /// 符号缺失 → 优雅降级：isAvailable=false、方法 nil/no-op、不 crash。
    func testDegradeWhenSymbolsMissing() {
        let shim = MediaRemoteShim(path: "/nonexistent/no-such-binary")
        XCTAssertFalse(shim.isAvailable)
        XCTAssertNil(shim.nowPlayingApplicationPID())
        XCTAssertNil(shim.nowPlayingInfo())
        XCTAssertNil(shim.isNowPlaying())
        shim.registerForNowPlayingNotifications() // no-op 不 crash
    }

    /// 默认路径探测不 crash（仅 dlopen+dlsym，不调用符号；
    /// 调用形态校准归 T2.30 真机 + 公证构建，D25 #3/A18）。
    func testDefaultPathProbeDoesNotCrash() {
        let shim = MediaRemoteShim()
        _ = shim.isAvailable // 探测结果与系统版本相关，仅验证不 crash
    }
}

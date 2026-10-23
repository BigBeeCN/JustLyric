import XCTest
@testable import MediaSession

/// 会话分类规则测试（S3 §4）。
final class SessionRulesTests: XCTestCase {
    /// 首方规则表判类（小写归一）。
    func testKnownKinds() {
        XCTAssertEqual(SessionRules.kind(forBundleID: "com.Spotify.Client"), .musicApp)
        XCTAssertEqual(SessionRules.kind(forBundleID: "com.apple.Music"), .musicApp)
        XCTAssertEqual(SessionRules.kind(forBundleID: "com.netease.163Music"), .musicApp)
        XCTAssertEqual(SessionRules.kind(forBundleID: "com.google.Chrome"), .browser)
        XCTAssertEqual(SessionRules.kind(forBundleID: "com.unknown.app"), .unknown)
    }

    /// 默认启用：仅音乐 app（浏览器/视频/游戏默认不显示）。
    func testDefaultEnabled() {
        XCTAssertTrue(SessionRules.defaultEnabled(for: .musicApp))
        XCTAssertFalse(SessionRules.defaultEnabled(for: .browser))
        XCTAssertFalse(SessionRules.defaultEnabled(for: .video))
        XCTAssertFalse(SessionRules.defaultEnabled(for: .game))
    }

    /// 未知 app 首次询问（IsEnabledByDefault/IsEnabledByUser）。
    func testUnknownAppAskPolicy() {
        var policy = SessionPolicy()
        XCTAssertNil(
            policy.decision(forBundleID: "com.unknown.app", kind: .unknown),
            "未知 app 首次需询问"
        )
        policy.remember(bundleID: "com.unknown.app", enabled: true)
        XCTAssertEqual(policy.decision(forBundleID: "com.unknown.app", kind: .unknown), true)
        XCTAssertEqual(
            policy.decision(forBundleID: "com.Spotify.Client", kind: .musicApp),
            true,
            "已知 app 走默认"
        )
    }
}

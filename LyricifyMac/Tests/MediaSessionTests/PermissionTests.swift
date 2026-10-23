import LyricsCore
import XCTest
@testable import MediaSession

/// 权限与降级测试（S3 §7）。
final class PermissionTests: XCTestCase {
    /// 降级状态机：MediaRemote 不可用 → 仅直连 + 分发通知。
    func testDegradedMode() {
        XCTAssertEqual(PermissionGuide.mode(mediaRemoteAvailable: true), .full)
        XCTAssertEqual(PermissionGuide.mode(mediaRemoteAvailable: false), .directOnly)
    }

    /// Automation 被拒 → 引导设置页。
    func testAutomationGuidance() {
        XCTAssertFalse(PermissionGuide.shouldGuideToSettings(.authorized))
        XCTAssertFalse(PermissionGuide.shouldGuideToSettings(.notDetermined))
        XCTAssertTrue(PermissionGuide.shouldGuideToSettings(.denied))
        XCTAssertTrue(
            PermissionGuide.automationSettingsURL.absoluteString.contains("Privacy_Automation")
        )
    }

    /// 诊断快照组装（S5 §4）。
    func testDiagnosticSnapshot() {
        let snapshot = DiagnosticSnapshot(
            currentTrack: TrackRef(title: "T", artists: ["A"]),
            timelineElapsedMs: 12345,
            effectiveLatencyMs: 280,
            sourceHitCounts: ["lrclib": 3, "local_files": 1],
            mode: .directOnly
        )
        XCTAssertEqual(snapshot.currentTrack?.title, "T")
        XCTAssertEqual(snapshot.effectiveLatencyMs, 280)
        XCTAssertEqual(snapshot.sourceHitCounts["lrclib"], 3)
        XCTAssertEqual(snapshot.mode, .directOnly)
    }
}

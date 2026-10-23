import XCTest
@testable import MediaSession

/// 直连源与分发通知测试（S3 §2）。
final class DirectSourcesTests: XCTestCase {
    /// 桩执行器。
    private struct StubRunner: ScriptRunner {
        let output: String?
        func run(_ source: String) -> String? {
            output
        }
    }

    /// Music 脚本输出解析。
    func testMusicSnapshotParsing() {
        let source = MusicSource(runner: StubRunner(output: "测试曲名|合成歌手甲|合成专辑|240|12.5|playing"))
        let snapshot = source.currentSnapshot()
        XCTAssertEqual(snapshot?.track?.title, "测试曲名")
        XCTAssertEqual(snapshot?.track?.artists, ["合成歌手甲"])
        XCTAssertEqual(snapshot?.track?.durationMs, 240_000)
        XCTAssertEqual(snapshot?.playback?.status, .playing)
        XCTAssertEqual(snapshot?.session.kind, .musicApp)
    }

    /// Spotify 快照 bundle id 直连语义。
    func testSpotifySnapshot() {
        let source = SpotifySource(runner: StubRunner(output: "曲目B|艺人B|专辑B|200|0|paused"))
        let snapshot = source.currentSnapshot()
        XCTAssertEqual(snapshot?.track?.bundleID, "com.spotify.client")
        XCTAssertEqual(snapshot?.playback?.status, .paused)
    }

    /// 直连优先规则（S3 §2）。
    func testDirectConnectionPriority() {
        XCTAssertLessThan(
            DirectConnectionPriority.rank(forMediaSourceID: "music"),
            DirectConnectionPriority.rank(forMediaSourceID: "mediaremote")
        )
        XCTAssertLessThan(
            DirectConnectionPriority.rank(forMediaSourceID: "spotify"),
            DirectConnectionPriority.rank(forMediaSourceID: "mediaremote")
        )
    }

    /// D34：≥50 并发压力（串行规则常驻回归——NSAppleScript 非线程安全）。
    func testScriptRunnerSerializesUnderConcurrency() {
        let runner = NSAppleScriptRunner()
        let lock = NSLock()
        var successes = 0
        let group = DispatchGroup()
        for _ in 0 ..< 60 {
            group.enter()
            DispatchQueue.global().async {
                let result = runner.run("return \"ok\"")
                if result == "ok" {
                    lock.lock()
                    successes += 1
                    lock.unlock()
                }
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 30), .success)
        XCTAssertEqual(successes, 60, "串行化下 60 并发全部成功（D34）")
    }

    /// 分发通知 userInfo → 事件。
    func testDistributedNotificationParsing() {
        let events = DistributedNotificationSource.events(
            fromUserInfo: [
                "Name": "通知曲名",
                "Artist": "通知艺人",
                "Album": "通知专辑",
                "Total Time": 180_000,
                "Player State": "playing",
            ],
            at: 0
        )
        XCTAssertEqual(events.count, 2)
        guard case let .track(track?) = events[0] else {
            return XCTFail("首事件应为 track")
        }
        XCTAssertEqual(track.title, "通知曲名")
        XCTAssertEqual(track.durationMs, 180_000)
        guard case let .playback(state) = events[1] else {
            return XCTFail("次事件应为 playback")
        }
        XCTAssertEqual(state.status, .playing)
    }
}

import LyricsCore
import XCTest
@testable import MediaSession

/// NowPlayingAggregator 测试（S3 §1；S6 §3-1；S7 D26 #5 事件顺序与防抖）。
final class AggregatorTests: XCTestCase {
    /// 测试时钟。
    private final class TestClock: @unchecked Sendable {
        var t: TimeInterval = 0
    }

    private func makeSession(_ bundleID: String = "com.example.player") -> SessionInfo {
        SessionInfo(bundleID: bundleID, displayName: "Player", kind: .musicApp)
    }

    private func makeTrack(_ title: String, isrc: String? = nil) -> TrackRef {
        TrackRef(title: title, artists: ["合成歌手甲"], isrc: isrc)
    }

    /// S6 §3-1：事件序列 开/播/切歌/暂停/seek → 状态正确。
    func testEventSequence() async {
        let aggregator = NowPlayingAggregator()
        let session = makeSession()
        let trackA = makeTrack("曲目A")
        let trackB = makeTrack("曲目B")

        await aggregator.handle(.sessionOpened(session))
        await aggregator.handle(.playback(PlaybackState(status: .playing, rate: 1.0)))
        await aggregator.handle(.track(trackA))
        await aggregator.handle(.timeline(TimelineSample(elapsedMs: 5000, rate: 1.0, at: 1)))
        await aggregator.handle(.track(trackB))
        await aggregator.handle(.playback(PlaybackState(status: .paused, rate: 0)))

        let current = await aggregator.current
        XCTAssertEqual(current?.title, "曲目B")
        let playback = await aggregator.playback
        XCTAssertEqual(playback?.status, .paused)
    }

    /// D26 #5：focusedChanged 携带 TrackRef 快照（nil=无焦点）。
    func testFocusedChangedSnapshot() async {
        let aggregator = NowPlayingAggregator()
        let session = makeSession()
        await aggregator.handle(.sessionOpened(session))
        await aggregator.handle(.focusedChanged(session: session, track: makeTrack("焦点曲")))
        var current = await aggregator.current
        XCTAssertEqual(current?.title, "焦点曲")

        await aggregator.handle(.focusedChanged(session: nil, track: nil))
        current = await aggregator.current
        XCTAssertNil(current, "nil 快照 = 无焦点")
    }

    /// D26 #5：同 track key 防抖 ≤300ms；不跨曲目合并。
    func testTrackDebounceAndNoCrossTrackMerge() async {
        let clock = TestClock()
        let aggregator = NowPlayingAggregator(debounceMs: 300, now: { clock.t })
        let trackA = makeTrack("曲目A", isrc: "TESTISRC0001")
        let trackB = makeTrack("曲目B", isrc: "TESTISRC0002")

        let first = await aggregator.handle(.track(trackA))
        XCTAssertTrue(first)

        clock.t = 0.1
        let duplicate = await aggregator.handle(.track(trackA))
        XCTAssertFalse(duplicate, "同 key 300ms 内防抖")

        let other = await aggregator.handle(.track(trackB))
        XCTAssertTrue(other, "不跨曲目合并")

        clock.t = 0.5
        let later = await aggregator.handle(.track(trackA))
        XCTAssertTrue(later, "超过 300ms 允许重复")
    }

    /// D26 #5：sessionOpened 先于 track 时状态完整（顺序契约）。
    func testSessionOrderingContract() async {
        let aggregator = NowPlayingAggregator()
        let session = makeSession()
        await aggregator.handle(.sessionOpened(session))
        await aggregator.handle(.track(makeTrack("曲目A")))
        let focused = await aggregator.focusedSession
        XCTAssertEqual(focused?.bundleID, session.bundleID, "会话已注册后 track 事件归属明确")
    }

    /// attach：从 MediaSource 事件流消费（S6 §3-1 注入形态）。
    func testAttachConsumesSourceStream() async {
        final class MockSource: MediaSource, @unchecked Sendable {
            let id = "mock"
            var continuation: AsyncStream<MediaEvent>.Continuation?
            let stream: AsyncStream<MediaEvent>
            init() {
                var captured: AsyncStream<MediaEvent>.Continuation?
                stream = AsyncStream { captured = $0 }
                continuation = captured
            }

            var events: AsyncStream<MediaEvent> {
                stream
            }

            func currentSnapshot() -> MediaSnapshot? {
                nil
            }
        }

        let source = MockSource()
        let aggregator = NowPlayingAggregator()
        let stop = await aggregator.attach(source)

        let session = makeSession()
        source.continuation?.yield(.sessionOpened(session))
        source.continuation?.yield(.track(makeTrack("流式曲目")))

        // 轮询等待事件消费。
        var title: String?
        for _ in 0 ..< 50 {
            title = await aggregator.current?.title
            if title == "流式曲目" {
                break
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(title, "流式曲目")
        stop()
    }
}

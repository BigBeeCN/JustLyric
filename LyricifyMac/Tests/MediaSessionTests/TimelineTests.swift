import XCTest
@testable import MediaSession

/// TimelineProvider 测试（S3 §3；S6 §3-2/-3）。
final class TimelineTests: XCTestCase {
    /// S6 §3-2：1s 稀疏样本插值连续。
    func testSparseSamplesInterpolation() {
        let provider = TimelineProvider()
        provider.ingest(TimelineSample(elapsedMs: 0, rate: 1.0, at: 0))
        provider.ingest(TimelineSample(elapsedMs: 1000, rate: 1.0, at: 1))
        XCTAssertEqual(Double(provider.elapsed(now: 0.5)), 500, accuracy: 30)
        XCTAssertEqual(Double(provider.elapsed(now: 1.5)), 1500, accuracy: 30)
        XCTAssertLessThanOrEqual(provider.elapsed(now: 0.7), provider.elapsed(now: 1.2), "单调连续")
    }

    /// S6 §3-2：1000ms+ 跳变识别为 seek 并通知。
    func testSeekJumpDetection() {
        var seekTarget: Int?
        let provider = TimelineProvider()
        provider.onSeek = { seekTarget = $0 }
        provider.ingest(TimelineSample(elapsedMs: 0, rate: 1.0, at: 0))
        provider.ingest(TimelineSample(elapsedMs: 5000, rate: 1.0, at: 1))
        XCTAssertEqual(seekTarget, 5000, "跳变通知")
        XCTAssertEqual(Double(provider.elapsed(now: 1)), 5000, accuracy: 5)
    }

    /// 软校正：<250ms 指数平滑吸收（α=0.2）。
    func testSoftCorrectionSmoothing() {
        let provider = TimelineProvider()
        provider.ingest(TimelineSample(elapsedMs: 0, rate: 1.0, at: 0))
        // 漂移 100ms：吸收 20ms。
        provider.ingest(TimelineSample(elapsedMs: 1100, rate: 1.0, at: 1))
        let elapsed = provider.elapsed(now: 1)
        XCTAssertEqual(elapsed, 1020, accuracy: 5)
    }

    /// 快速校正：250–1000ms 直接对齐样本。
    func testFastCorrection() {
        let provider = TimelineProvider()
        provider.ingest(TimelineSample(elapsedMs: 0, rate: 1.0, at: 0))
        provider.ingest(TimelineSample(elapsedMs: 1500, rate: 1.0, at: 1)) // 漂移 500ms
        XCTAssertEqual(Double(provider.elapsed(now: 1)), 1500, accuracy: 5)
    }

    /// 暂停冻结/恢复推算（S3 §3：不倒流）。
    func testPauseFreezeAndNoReversal() {
        let provider = TimelineProvider()
        provider.ingest(TimelineSample(elapsedMs: 0, rate: 1.0, at: 0))
        let atPause = provider.elapsed(now: 1)
        XCTAssertEqual(atPause, 1000, accuracy: 5)
        provider.apply(playback: PlaybackState(status: .paused, rate: 0), at: 1)
        XCTAssertEqual(provider.elapsed(now: 5), atPause, "暂停冻结")
        XCTAssertEqual(provider.elapsed(now: 9), atPause, "冻结持续不增长不倒流")
        // 恢复后继续推进。
        provider.apply(playback: PlaybackState(status: .playing, rate: 1.0), at: 5)
        XCTAssertGreaterThan(provider.elapsed(now: 6), atPause)
    }

    /// S6 §3-3：forceInternalTimer 忽略后续样本仅按 rate 自走。
    func testForceInternalTimer() {
        let provider = TimelineProvider()
        provider.ingest(TimelineSample(elapsedMs: 0, rate: 1.0, at: 0))
        provider.setForceInternalTimer(true)
        provider.ingest(TimelineSample(elapsedMs: 9000, rate: 1.0, at: 1)) // 跳变样本被忽略
        XCTAssertEqual(Double(provider.elapsed(now: 1)), 1000, accuracy: 5, "仅按 rate 自走")
    }

    /// 倍速参与推算（S3 §3、S6 §A7 前置）。
    func testRateScaling() {
        let provider = TimelineProvider()
        provider.apply(playback: PlaybackState(status: .playing, rate: 1.5), at: 0)
        XCTAssertEqual(Double(provider.elapsed(now: 1)), 1500, accuracy: 5)
        provider.apply(playback: PlaybackState(status: .playing, rate: 2.0), at: 1)
        XCTAssertEqual(Double(provider.elapsed(now: 2)), 3500, accuracy: 5)
    }

    /// D43 回归：陈旧序列不得拉动时钟（MR elapsed 事件驱动陈旧值防御）。
    func testStaleSamplesDoNotDragClock() {
        var seekFired = 0
        let provider = TimelineProvider()
        provider.onSeek = { _ in seekFired += 1 }
        provider.ingest(TimelineSample(elapsedMs: 1000, rate: 1.0, at: 1.0))
        // 陈旧序列：elapsed 恒 1000、墙钟前进——不得拉回、不得 seek。
        provider.ingest(TimelineSample(elapsedMs: 1000, rate: 1.0, at: 2.0))
        provider.ingest(TimelineSample(elapsedMs: 1000, rate: 1.0, at: 3.0))
        XCTAssertEqual(provider.elapsed(now: 3.0), 3000, accuracy: 5, "内部时钟持续推算不被拉回")
        XCTAssertEqual(seekFired, 0, "陈旧样本绝不触发 seek")

        // 真实跳变（elapsed 前进）恢复校正。
        provider.ingest(TimelineSample(elapsedMs: 4200, rate: 1.0, at: 4.0))
        XCTAssertGreaterThan(provider.elapsed(now: 4.0), 3000)
    }

    /// 120Hz 插值回调启停（S3 §3）。
    func testInterpolationStartStop() {
        let provider = TimelineProvider()
        let stop = provider.startInterpolation(hz: 120) { _ in }
        stop()
    }
}

import Foundation
import LyricsCore

/// 时间轴平滑器（S3 §3；逐字精准的核心）。
///
/// 规格：
/// - 状态机 `stopped / playing(rate) / seeking`；
/// - `elapsed(now) = baseElapsed + (now - baseTime) × rate`（内部时钟推算）；
/// - 样本软校正：`|推算-样本| < 250ms` → 指数平滑吸收（α=0.2）；
///   `250ms–1000ms` → 快速校正；`>1000ms` → 视为 seek，跳变并通知；
/// - 暂停/恢复：冻结/恢复推算，**不允许时间倒流**；
/// - `forceInternalTimer`：忽略后续样本仅按 rate 自走（每 app 可配）；
/// - 倍速（0.5×–2×）参与推算；ProMotion 按 120Hz 提供插值回调。
public final class TimelineProvider: @unchecked Sendable {
    /// 软校正阈值（毫秒，S3 §3）。
    public static let softCorrectionMs = 250
    /// 快速校正上限/seek 判定阈值（毫秒，S3 §3）。
    public static let seekThresholdMs = 1000
    /// 指数平滑系数（S3 §3）。
    public static let smoothingAlpha = 0.2

    /// 状态机。
    public enum State: Sendable, Equatable {
        /// 停止。
        case stopped
        /// 播放（倍速）。
        case playing(rate: Double)
        /// seek 中。
        case seeking
    }

    /// 当前状态。
    public private(set) var state: State = .stopped
    /// seek 通知（载荷 = 跳变后毫秒）。
    public var onSeek: ((Int) -> Void)?

    private let lock = NSLock()
    private var baseElapsedMs: Double = 0
    private var baseTime: TimeInterval = 0
    private var forceInternal = false
    // D43 陈旧样本防御（产品级）：连续样本 elapsed 不变且墙钟前进 → 标记陈旧。
    private var lastSampleElapsedMs: Int?
    private var lastSampleAt: TimeInterval?

    /// 创建平滑器。
    /// - Parameter baseTime: 初始时钟（默认 0，测试注入）。
    public init(baseTime: TimeInterval = 0) {
        self.baseTime = baseTime
    }

    // MARK: - 样本摄取

    /// 吸收系统样本（S3 §3 软校正三分支）。
    /// - Parameter sample: 时间轴样本。
    public func ingest(_ sample: TimelineSample) {
        lock.lock()
        defer { lock.unlock() }

        // 状态跟随样本（rate 变化先结算再切换）。
        if case let .playing(rate) = state, rate == sample.rate {
            // 无变化
        } else {
            baseElapsedMs = elapsedLocked(now: sample.at)
            baseTime = sample.at
            state = .playing(rate: sample.rate)
        }
        if forceInternal {
            return // D28/S3 §3：仅按 rate 自走
        }

        // D43：陈旧样本不参与软校正、绝不触发 seek（MR elapsed 事件驱动陈旧值防御）。
        if case let .playing(rate) = state, rate > 0,
           let lastElapsed = lastSampleElapsedMs,
           let lastAt = lastSampleAt,
           sample.at > lastAt,
           sample.elapsedMs == lastElapsed
        {
            return
        }
        let establishing = lastSampleAt == nil
        lastSampleElapsedMs = sample.elapsedMs
        lastSampleAt = sample.at

        // 首样本（含状态重置后）仅立基准，不作 seek（产品语义：seek=播放中跳变）。
        if establishing {
            baseElapsedMs = Double(sample.elapsedMs)
            baseTime = sample.at
            return
        }

        let predicted = elapsedLocked(now: sample.at)
        let drift = Double(sample.elapsedMs) - predicted

        switch abs(drift) {
        case ..<Double(Self.softCorrectionMs):
            // 指数平滑吸收（α=0.2）。
            baseElapsedMs = predicted + drift * Self.smoothingAlpha
            baseTime = sample.at
        case ..<Double(Self.seekThresholdMs):
            // 快速校正。
            baseElapsedMs = Double(sample.elapsedMs)
            baseTime = sample.at
        default:
            // seek：跳变并通知。
            baseElapsedMs = Double(sample.elapsedMs)
            baseTime = sample.at
            state = .seeking
            let target = sample.elapsedMs
            onSeek?(target)
            state = .playing(rate: sample.rate)
        }
    }

    // MARK: - 状态

    /// 播放状态迁移（暂停冻结/恢复推算）。
    /// - Parameter playback: 播放状态。
    public func apply(playback: PlaybackState, at now: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        // 先按旧状态结算落库；状态迁移重置陈旧标记（D43：仅此三类事件重置基准）。
        baseElapsedMs = elapsedLocked(now: now)
        lastSampleElapsedMs = nil
        lastSampleAt = nil
        baseTime = now
        switch playback.status {
        case .playing:
            state = .playing(rate: playback.rate)
        case .paused:
            state = .playing(rate: 0) // 冻结：rate 归零不倒流
        case .stopped:
            state = .stopped
        }
    }

    /// `forceInternalTimer`（S3 §3：每 app 可配）。
    /// - Parameter enabled: 是否启用。
    public func setForceInternalTimer(_ enabled: Bool) {
        lock.lock()
        forceInternal = enabled
        lock.unlock()
    }

    /// 当前推算时长（毫秒）。
    /// - Parameter now: 当前时刻。
    /// - Returns: 已播毫秒。
    public func elapsed(now: TimeInterval) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return Int(elapsedLocked(now: now).rounded())
    }

    /// 120Hz 插值回调（ProMotion，S3 §3）。
    /// - Parameters:
    ///   - hz: 回调频率（默认 120）。
    ///   - handler: 插值回调（毫秒）。
    /// - Returns: 停止函数。
    public func startInterpolation(
        hz: Double = 120,
        handler: @escaping @Sendable (Int) -> Void
    ) -> @Sendable () -> Void {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: 1.0 / max(1, hz))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            handler(elapsed(now: Date().timeIntervalSince1970))
        }
        timer.resume()
        return { timer.cancel() }
    }

    // MARK: - 私有

    /// 内部推算（加锁域内）：字面公式 `baseElapsed + (now - baseTime) × rate`（S3 §3）。
    private func elapsedLocked(now: TimeInterval) -> Double {
        let rate: Double = switch state {
        case let .playing(r):
            r
        case .stopped, .seeking:
            0
        }
        return baseElapsedMs + (now - baseTime) * 1000.0 * rate
    }
}

/// S7 D30 #5：渲染组件经 TimelineProviding 协议消费本类型（MediaSession 不依赖 RenderKit）。
extension TimelineProvider: TimelineProviding {}

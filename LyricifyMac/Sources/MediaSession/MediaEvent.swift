import Foundation
import LyricsCore

/// 播放状态（S3 §1：playing/paused/stopped + rate）。
public struct PlaybackState: Sendable, Equatable {
    /// 播放状态。
    public enum Status: Sendable, Equatable {
        /// 播放中。
        case playing
        /// 暂停。
        case paused
        /// 停止。
        case stopped
    }

    /// 状态。
    public let status: Status
    /// 倍速（0.5–2×）。
    public let rate: Double

    /// 创建播放状态。
    /// - Parameters:
    ///   - status: 状态。
    ///   - rate: 倍速。
    public init(status: Status, rate: Double) {
        self.status = status
        self.rate = rate
    }
}

/// 时间轴样本（S3 §1：`at` = `CACurrentMediaTime`）。
public struct TimelineSample: Sendable, Equatable {
    /// 已播时长（毫秒）。
    public let elapsedMs: Int
    /// 倍速。
    public let rate: Double
    /// 采样时刻（秒）。
    public let at: TimeInterval

    /// 创建时间轴样本。
    /// - Parameters:
    ///   - elapsedMs: 已播时长（毫秒）。
    ///   - rate: 倍速。
    ///   - at: 采样时刻。
    public init(elapsedMs: Int, rate: Double, at: TimeInterval) {
        self.elapsedMs = elapsedMs
        self.rate = rate
        self.at = at
    }
}

/// 媒体会话事件（S3 §1；S7 D26 #5：`focusedChanged` 携带 `TrackRef` 快照）。
public enum MediaEvent: Sendable {
    /// 会话开启（必先于该会话 `track` 事件，D26 #5）。
    case sessionOpened(SessionInfo)
    /// 会话关闭。
    case sessionClosed(SessionInfo)
    /// 焦点变化（快照 `nil` = 无焦点）。
    case focusedChanged(session: SessionInfo?, track: TrackRef?)
    /// 播放状态。
    case playback(PlaybackState)
    /// 曲目变化。
    case track(TrackRef?)
    /// 时间轴样本。
    case timeline(TimelineSample)
}

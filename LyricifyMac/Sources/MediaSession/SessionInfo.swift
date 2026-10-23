import Foundation
import LyricsCore

/// 会话分类（S3 §4）。
public enum SessionKind: String, Sendable, Equatable {
    /// 音乐 app。
    case musicApp
    /// 播客。
    case podcast
    /// 视频。
    case video
    /// 浏览器。
    case browser
    /// 游戏。
    case game
    /// 即时通讯。
    case im
    /// 未知。
    case unknown
}

/// 会话信息（S3 §2：至少含 bundleID/displayName/icon/sessionType）。
///
/// > Note: `iconData` 为原始图标数据（App 层转 NSImage，实现级选择）。
public struct SessionInfo: Sendable, Equatable {
    /// bundle id。
    public let bundleID: String
    /// 显示名。
    public let displayName: String
    /// 图标数据。
    public let iconData: Data?
    /// 会话分类。
    public let kind: SessionKind

    /// 创建会话信息。
    /// - Parameters:
    ///   - bundleID: bundle id。
    ///   - displayName: 显示名。
    ///   - iconData: 图标数据，可选。
    ///   - kind: 会话分类。
    public init(bundleID: String, displayName: String, iconData: Data? = nil, kind: SessionKind) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.iconData = iconData
        self.kind = kind
    }
}

/// 会话快照（`MediaSource.currentSnapshot()` 载荷；字段名为实现级定义，A17 待批）。
public struct MediaSnapshot: Sendable, Equatable {
    /// 会话信息。
    public let session: SessionInfo
    /// 当前曲目。
    public let track: TrackRef?
    /// 播放状态。
    public let playback: PlaybackState?
    /// 当前位置（毫秒，直连 seek/position 精确读取）。
    public let timelineElapsedMs: Int?

    /// 创建会话快照。
    /// - Parameters:
    ///   - session: 会话信息。
    ///   - track: 当前曲目，可选。
    ///   - playback: 播放状态，可选。
    ///   - timelineElapsedMs: 当前位置毫秒，可选。
    public init(
        session: SessionInfo,
        track: TrackRef? = nil,
        playback: PlaybackState? = nil,
        timelineElapsedMs: Int? = nil
    ) {
        self.session = session
        self.track = track
        self.playback = playback
        self.timelineElapsedMs = timelineElapsedMs
    }
}

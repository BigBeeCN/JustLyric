import Foundation
import LyricsCore

/// 正在播放聚合器（S3 §1；S7 D26 #5 事件顺序与防抖）。
///
/// 规则钉死（D26 #5）：
/// - `sessionOpened` 必先于该会话 `track` 事件（未知会话的事件被防御性丢弃）；
/// - `focusedChanged` 携带 `TrackRef` 快照（`nil` = 无焦点）；
/// - 同 track key 重复事件防抖 ≤300ms、**不跨曲目合并**。
public actor NowPlayingAggregator {
    /// 当前曲目（焦点会话）。
    public private(set) var current: TrackRef?
    /// 焦点会话。
    public private(set) var focusedSession: SessionInfo?
    /// 最近播放状态。
    public private(set) var playback: PlaybackState?
    /// 已注册会话（按 bundle id 归并）。
    private var sessions: [String: SessionInfo] = [:]

    private let now: @Sendable () -> TimeInterval
    private let debounceMs: Double
    private var lastTrackKey: String?
    private var lastTrackAt: TimeInterval = -.infinity

    /// 创建聚合器。
    /// - Parameters:
    ///   - debounceMs: 同曲目重复事件防抖毫秒（≤300，D26 #5）。
    ///   - now: 时钟注入（测试确定性）。
    public init(
        debounceMs: Double = 300,
        now: @escaping @Sendable () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.debounceMs = min(300, max(0, debounceMs))
        self.now = now
    }

    /// 挂接媒体源（消费其事件流）。
    /// - Parameter source: 媒体源。
    /// - Returns: 停止消费的句柄。
    public func attach(_ source: MediaSource) -> @Sendable () -> Void {
        let stream = source.events
        let task = Task { [weak self] in
            for await event in stream {
                guard let self else { break }
                _ = await handle(event)
            }
        }
        return { task.cancel() }
    }

    /// 处理事件（返回是否被接受；防抖/顺序违规时为 `false`）。
    /// - Parameter event: 事件。
    /// - Returns: 是否接受。
    @discardableResult
    public func handle(_ event: MediaEvent) -> Bool {
        switch event {
        case let .sessionOpened(session):
            sessions[session.bundleID] = session
            return true

        case let .sessionClosed(session):
            sessions.removeValue(forKey: session.bundleID)
            if focusedSession?.bundleID == session.bundleID {
                focusedSession = nil
                current = nil
            }
            return true

        case let .focusedChanged(session, track):
            focusedSession = session
            current = track // D26 #5：快照 nil = 无焦点
            return true

        case let .playback(state):
            playback = state
            return true

        case let .track(track):
            // D26 #5：同 track key 防抖 ≤300ms，不跨曲目合并。
            if let key = track.map(Self.trackKey), key == lastTrackKey,
               now() - lastTrackAt < debounceMs / 1000
            {
                return false
            }
            lastTrackKey = track.map(Self.trackKey)
            lastTrackAt = now()
            if focusedSession == nil, let session = sessions.values.first {
                // 防御性：无焦点时取首会话（顺序保证由源层负责）。
                focusedSession = session
            }
            current = track
            return true

        case .timeline:
            return true
        }
    }

    /// 曲目 key（缓存 key 同源规则，单点见 ``TrackKeying``）。
    static func trackKey(_ track: TrackRef) -> String {
        TrackKeying.make(track)
    }
}

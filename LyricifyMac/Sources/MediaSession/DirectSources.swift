import Foundation
import LyricsCore

/// AppleScript 执行抽象（测试可注入 stub）。
public protocol ScriptRunner: Sendable {
    /// 执行脚本并返回文本结果（失败 `nil`）。
    /// - Parameter source: AppleScript 源。
    /// - Returns: 文本结果。
    func run(_ source: String) -> String?
}

/// `NSAppleScript` 默认实现。
///
/// > Warning: `NSAppleScript` **非线程安全**（T2.30 实测：并发调用致静默失败）——
/// > 全部执行串行化于私有队列。
public struct NSAppleScriptRunner: ScriptRunner {
    /// 串行执行队列（线程安全修复）。
    private static let queue = DispatchQueue(label: "com.lyricifymac.applescript")

    /// 创建执行器。
    public init() {}

    public func run(_ source: String) -> String? {
        Self.queue.sync {
            guard let script = NSAppleScript(source: source) else { return nil }
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            return error == nil ? result.stringValue : nil
        }
    }
}

/// 直连源优先级（S3 §2：直连与 MediaRemote 同时命中时直连优先）。
public enum DirectConnectionPriority {
    /// 源优先级（数值小者优先）。
    /// - Parameter mediaSourceID: 媒体源 id（"music"/"spotify"/"mediaremote"）。
    /// - Returns: 优先级。
    public static func rank(forMediaSourceID mediaSourceID: String) -> Int {
        switch mediaSourceID.lowercased() {
        case "music", "spotify":
            0 // 直连优先
        case "mediaremote":
            1
        default:
            2
        }
    }
}

/// Music 直连源（S3 §2：`tell application "Music"`，含 seek/position 精确读取）。
public struct MusicSource: MediaSource {
    public let id = "music"

    private let runner: ScriptRunner

    /// 创建 Music 直连源。
    /// - Parameter runner: 脚本执行器。
    public init(runner: ScriptRunner = NSAppleScriptRunner()) {
        self.runner = runner
    }

    public var events: AsyncStream<MediaEvent> {
        AsyncStream { $0.finish() } // 事件由聚合层轮询/通知桥接（T2.21 组装）
    }

    /// 读取当前曲目（脚本值：`name|artist|album|durationSec|positionSec|state`）。
    /// - Returns: 快照。
    public func currentSnapshot() -> MediaSnapshot? {
        let source = """
        tell application "Music"
        set n to name of current track
        set a to artist of current track
        set al to album of current track
        set d to duration of current track
        set p to player position
        set s to (player state as text)
        return n & "|" & a & "|" & al & "|" & (d as text) & "|" & (p as text) & "|" & s
        end tell
        """
        guard let output = runner.run(source) else { return nil }
        return Self.snapshot(fromScriptOutput: output, bundleID: "com.apple.Music")
    }

    /// 脚本输出 → 快照（供测试与复用）。
    static func snapshot(fromScriptOutput output: String, bundleID: String) -> MediaSnapshot? {
        let parts = output.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 6 else { return nil }
        let durationMs = (Double(parts[3]).map { Int($0 * 1000) })
        let elapsedMs = (Double(parts[4]).map { Int($0 * 1000) })
        let track = TrackRef(
            title: parts[0],
            artists: [parts[1]].filter { !$0.isEmpty },
            album: parts[2].isEmpty ? nil : parts[2],
            durationMs: durationMs,
            bundleID: bundleID
        )
        let state: PlaybackState.Status = parts[5] == "playing" ? .playing : (parts[5] == "paused" ? .paused : .stopped)
        let playback = PlaybackState(status: state, rate: state == .playing ? 1.0 : 0)
        let session = SessionInfo(
            bundleID: bundleID,
            displayName: bundleID == "com.apple.Music" ? "Music" : "Spotify",
            kind: .musicApp
        )
        return MediaSnapshot(
            session: session,
            track: track,
            playback: playback,
            timelineElapsedMs: elapsedMs
        )
    }
}

/// Spotify 直连源（S3 §2：player position/current track）。
public struct SpotifySource: MediaSource {
    public let id = "spotify"

    private let runner: ScriptRunner

    /// 创建 Spotify 直连源。
    /// - Parameter runner: 脚本执行器。
    public init(runner: ScriptRunner = NSAppleScriptRunner()) {
        self.runner = runner
    }

    public var events: AsyncStream<MediaEvent> {
        AsyncStream { $0.finish() }
    }

    /// 读取当前曲目。
    /// - Returns: 快照。
    public func currentSnapshot() -> MediaSnapshot? {
        let source = """
        tell application "Spotify"
        set n to name of current track
        set a to artist of current track
        set al to album of current track
        set d to duration of current track
        set p to player position
        set s to (player state as text)
        return n & "|" & a & "|" & al & "|" & (d as text) & "|" & (p as text) & "|" & s
        end tell
        """
        guard let output = runner.run(source) else { return nil }
        return MusicSource.snapshot(fromScriptOutput: output, bundleID: "com.spotify.client")
    }
}

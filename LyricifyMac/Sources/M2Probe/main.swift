import Darwin
import Foundation
import LyricsCore
import MediaSession
import Sources

/// M2Probe —— T2.30 真机验收采集工装（本地运行，零遥测；仅调用公开模块 API，
/// MediaRemote 私有符号仍仅在 MediaRemoteShim 内，红线不破）。
///
/// 用法：
///   m2probe symbols            五符号解析状态（证据①，nm 等价核验）
///   m2probe calibrate          五函数真机调用（D28 签名校准，证据②本地部分）
///   m2probe snapshot           当前"正在播放"快照（MediaRemote 全 app 路径）
///   m2probe drift <秒>         漂移采样（证据③方法与读数）
///   m2probe listen <秒>        分发通知事件采集（切歌/播放暂停）
///   m2probe lyrics             对当前曲目走 LyricsProvider（LRCLIB）命中歌词
let arguments = CommandLine.arguments
let command = arguments.count > 1 ? arguments[1] : "snapshot"

func section(_ title: String) {
    print("\n== \(title) ==")
}

let shim = MediaRemoteShim()

switch command {
case "symbols":
    section("五符号解析状态（证据①）")
    print("MediaRemote dlopen/dlsym 探测: \(shim.isAvailable ? "OK" : "FAILED")")
    for item in shim.symbolStatus() {
        print("\(item.resolved ? "[OK]     " : "[MISSING]") \(item.name)")
    }

case "calibrate":
    section("真机调用校准（D28 签名验证）")
    print("isAvailable: \(shim.isAvailable)")
    fflush(stdout)
    let step = arguments.count > 2 ? arguments[2] : "all"
    if step == "all" || step == "pid" {
        fputs("[step] GetNowPlayingApplicationPID …\n", stdout); fflush(stdout)
        let pid = shim.nowPlayingApplicationPID()
        print("nowPlayingApplicationPID: \(pid.map(String.init) ?? "nil")")
        fflush(stdout)
    }
    if step == "all" || step == "playing" {
        fputs("[step] GetNowPlayingApplicationIsPlaying …\n", stdout); fflush(stdout)
        let playing = shim.isNowPlaying()
        print("isNowPlaying: \(playing.map(String.init) ?? "nil")")
        fflush(stdout)
    }
    if step == "all" || step == "info" {
        fputs("[step] GetNowPlayingInfo …\n", stdout); fflush(stdout)
        if let info = shim.nowPlayingInfo() {
            for key in info.keys.sorted() {
                let value = info[key]
                let text = value.map { String(describing: $0).prefix(60) } ?? "nil"
                print("info[\(key)]: \(text)")
            }
        } else {
            print("nowPlayingInfo: nil")
        }
        fflush(stdout)
    }
    if step == "all" || step == "register" {
        fputs("[step] Register …\n", stdout); fflush(stdout)
        shim.registerForNowPlayingNotifications()
        print("registerForNowPlayingNotifications: OK")
        fputs("[step] Unregister …\n", stdout); fflush(stdout)
        shim.unregisterForNowPlayingNotifications()
        print("unregisterForNowPlayingNotifications: OK")
        fflush(stdout)
    }
    print("校准结果: 调用完成无 SIGTRAP（isAvailable=\(shim.isAvailable)）")

case "snapshot":
    section("正在播放快照（MediaRemote 全 app 路径）")
    if let info = shim.nowPlayingInfo() {
        print("title: \(info["title"] ?? "nil")")
        print("artist: \(info["artist"] ?? "nil")")
        print("album: \(info["album"] ?? "nil")")
        print("duration: \(info["duration"] ?? "nil")")
        print("elapsedTime: \(info["elapsedTime"] ?? "nil")")
        print("playbackRate: \(info["playbackRate"] ?? "nil")")
    } else {
        print("无正在播放会话（MediaRemote 返回 nil）")
    }
    if let pid = shim.nowPlayingApplicationPID() {
        print("app PID: \(pid)")
    }

case "drift":
    let seconds = arguments.count > 2 ? Double(arguments[2]) ?? 60 : 60
    section("漂移采样（证据③方法：MediaRemote elapsedTime vs 墙钟×rate）")
    var baseWall: TimeInterval?
    var baseElapsed: Double?
    var lastWall: TimeInterval?
    var lastElapsed: Double?
    var worstIntervalDrift = 0.0
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        if let info = shim.nowPlayingInfo(),
           let elapsed = (info["elapsedTime"] as? NSNumber)?.doubleValue
        {
            let rate = (info["playbackRate"] as? NSNumber)?.doubleValue ?? 1.0
            let wall = Date().timeIntervalSince1970
            if baseWall == nil {
                baseWall = wall
                baseElapsed = elapsed
                print(String(format: "T+0.0s  elapsed=%.3f  rate=%.2f", elapsed, rate))
            } else if let lw = lastWall, let le = lastElapsed, rate > 0 {
                let intervalDrift = (elapsed - le) - (wall - lw) * rate
                worstIntervalDrift = max(worstIntervalDrift, abs(intervalDrift))
                lastWall = wall
                lastElapsed = elapsed
            }
            if lastWall == nil {
                lastWall = wall
                lastElapsed = elapsed
            }
        }
        Thread.sleep(forTimeInterval: 2)
    }
    if let bw = baseWall, let be = baseElapsed, let lw = lastWall, let le = lastElapsed {
        let rate = (shim.nowPlayingInfo()?["playbackRate"] as? NSNumber)?.doubleValue ?? 1.0
        let cumulative = (le - be) - (lw - bw) * rate
        print(String(format: "采样时长 %.1fs", lw - bw))
        print(String(format: "累计漂移 %.1f ms", cumulative * 1000))
        print(String(format: "区间最大漂移 %.1f ms", worstIntervalDrift * 1000))
    } else {
        print("采样窗口内无正在播放会话")
    }

case "listen":
    let seconds = arguments.count > 2 ? Double(arguments[2]) ?? 30 : 30
    section("事件采集（分发通知 + 100ms MediaRemote 轮询混合同一时间轴，\(Int(seconds))s）")
    let source = DistributedNotificationSource()
    let stop = source.start { event in
        let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
        switch event {
        case let .track(track):
            print("[\(stamp)] NOTE track: \(track?.title ?? "nil") — \(track?.artists.joined(separator: ",") ?? "")")
        case let .playback(state):
            print("[\(stamp)] NOTE playback: \(state.status) rate=\(state.rate)")
        default:
            print("[\(stamp)] NOTE other event")
        }
        fflush(stdout)
    }
    // 100ms 轮询 MediaRemote（检出时刻对比用）。
    final class PollState: @unchecked Sendable {
        var track: String?
        var playing: Bool?
    }
    let state = PollState()
    let poller = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
    poller.schedule(deadline: .now(), repeating: 0.1)
    poller.setEventHandler {
        let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
        let title = shim.nowPlayingInfo()?["title"] as? String
        let playing = shim.isNowPlaying()
        if title != state.track {
            print("[\(stamp)] POLL track: \(title ?? "nil")")
            fflush(stdout)
            state.track = title
        }
        if playing != state.playing {
            print("[\(stamp)] POLL playing: \(playing.map(String.init) ?? "nil")")
            fflush(stdout)
            state.playing = playing
        }
    }
    poller.resume()
    Thread.sleep(forTimeInterval: seconds)
    poller.cancel()
    stop()
    print("采集结束")

case "lyrics":
    section("取词链路（LRCLIB）")
    guard let info = shim.nowPlayingInfo(),
          let title = info["title"] as? String
    else {
        print("无正在播放曲目，跳过")
        exit(0)
    }
    let artists = (info["artist"] as? String).map { [$0] } ?? []
    let duration = (info["duration"] as? NSNumber).map { Int($0.doubleValue * 1000) }
    let track = TrackRef(title: title, artists: artists, durationMs: duration)
    print("TrackRef: \(title) — \(artists.joined(separator: ","))")
    let provider = LyricsProvider(adapters: [LRCLIBAdapter()])
    let preferences = SourcePreferences(order: [.lrclib], minMatch: .low)
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        let result = await provider.lyrics(for: track, pref: preferences)
        switch result {
        case let .found(data, source, quality):
            print("命中: source=\(source.identifier) quality=\(quality) lines=\(data.lines.count)")
            if let first = data.lines.first {
                print("首行: \(first.text)")
            }
        case let .missing(reason):
            print("未命中: \(reason)")
        }
        semaphore.signal()
    }
    semaphore.wait()

default:
    print("未知命令: \(command)")
}

// watch-direct：直连通道（SpotifySource）100ms 事件 + 2s 漂移采样（MediaRemote 盲区补证）。
// 漂移只在播放态累积；缺口 >5s 重置基准；每 60s 输出读数（防污染）。
if command == "watch-direct" {
    let seconds = arguments.count > 2 ? Double(arguments[2]) ?? 3600 : 3600
    section("直连通道采集（SpotifySource，\(Int(seconds))s，仅播放态累积漂移）")
    let spotify = SpotifySource()
    let pollState = WatchState()
    let queue = DispatchQueue(label: "com.lyricifymac.watchdirect") // 串行：NSAppleScript 线程安全
    let eventTimer = DispatchSource.makeTimerSource(queue: queue)
    eventTimer.schedule(deadline: .now(), repeating: 0.1)
    eventTimer.setEventHandler {
        let now = Date().timeIntervalSince1970
        guard let snapshot = spotify.currentSnapshot() else {
            if now - pollState.lastSeenWall > 5 {
                print(String(format: "[%.3f] GAP 查询失败（>5s），漂移基准重置", now))
                fflush(stdout)
                pollState.resetBase()
                pollState.lastSeenWall = now
            }
            return
        }
        pollState.lastSeenWall = now
        let title = snapshot.track?.title
        let playing = snapshot.playback?.status == .playing
        if title != pollState.lastTitle {
            let stamp = String(format: "%.3f", now)
            print("[\(stamp)] DIRECT track: \(title ?? "nil")")
            fflush(stdout)
            pollState.lastTitle = title
        }
        if playing != pollState.lastPlaying {
            let stamp = String(format: "%.3f", now)
            print("[\(stamp)] DIRECT playback: \(playing ? "playing" : "not-playing")")
            fflush(stdout)
            pollState.lastPlaying = playing
            pollState.resetBase() // 状态切换即重置基准
        }
        guard playing, let elapsedMs = snapshot.timelineElapsedMs else { return }
        let position = Double(elapsedMs) / 1000
        if now - pollState.lastSampleWall >= 2 {
            defer { pollState.lastSampleWall = now }
            if pollState.baseWall == nil {
                pollState.baseWall = now
                pollState.basePosition = position
                print(String(format: "[%.3f] DRIFT base position=%.3f", now, position))
                fflush(stdout)
                return
            }
            guard let bw = pollState.baseWall, let bp = pollState.basePosition else { return }
            if now - pollState.lastSampleWall > 5 {
                print(String(format: "[%.3f] GAP 中断，漂移基准重置", now))
                pollState.resetBase()
                return
            }
            let cumulative = (position - bp) - (now - bw)
            pollState.worst = max(pollState.worst, abs(cumulative - (pollState.lastCumulative ?? 0)))
            pollState.lastCumulative = cumulative
            print(String(format: "DRIFTSAMPLE %.3f pos=%.3f cum=%.1fms", now, position, cumulative * 1000))
            fflush(stdout)
            if now - pollState.lastReportWall >= 60 {
                pollState.lastReportWall = now
                print(String(format: "[%.3f] DRIFT 读数: T+%.0fs 累计 %.1f ms", now, now - bw, cumulative * 1000))
                fflush(stdout)
            }
        }
    }
    eventTimer.resume()
    Thread.sleep(forTimeInterval: seconds)
    eventTimer.cancel()
    if let bw = pollState.baseWall, let bp = pollState.basePosition,
       let finalElapsedMs = spotify.currentSnapshot()?.timelineElapsedMs
    {
        let position = Double(finalElapsedMs) / 1000
        let wall = Date().timeIntervalSince1970
        let cumulative = (position - bp) - (wall - bw)
        print(String(
            format: "直连漂移采样: 播放态时长 %.1fs 累计 %.1f ms 区间最大 %.1f ms",
            wall - bw,
            cumulative * 1000,
            pollState.worst * 1000
        ))
    } else {
        print("直连漂移采样: 窗口内无有效样本")
    }
    print("采集结束")
}

final class WatchState: @unchecked Sendable {
    var lastDirectTitle: String?
    var lastTitle: String?
    var lastPlaying: Bool?
    var lastSampleWall: TimeInterval = 0
    var lastSeenWall: TimeInterval = 0
    var lastReportWall: TimeInterval = 0
    var baseWall: TimeInterval?
    var basePosition: Double?
    var lastCumulative: Double?
    var worst: Double = 0
    func resetBase() {
        baseWall = nil
        basePosition = nil
        lastCumulative = nil
    }
}

// listen-mr：通知路径验证（Spike-3 定案：注册后订阅、userInfo 承载数据）。
if command == "listen-mr" {
    let seconds = arguments.count > 2 ? Double(arguments[2]) ?? 30 : 30
    section("MediaRemote 通知路径（\(Int(seconds))s）——网易云请保持播放")
    let shim2 = MediaRemoteShim()
    let stop = shim2.startNowPlayingListener { payload in
        let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
        let keys = payload.keys.sorted().map { "\($0)=\(String(describing: payload[$0]!).prefix(30))" }
        print("[\(stamp)] MRNOTIFY \(keys.joined(separator: " "))")
        fflush(stdout)
    }
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    stop()
    print("监听结束")
}

// m412：M4-12 演练采集（adapter 流 + 直连对照 + 漂移采样，同一时间轴）。
if command == "m412" {
    let seconds = arguments.count > 2 ? Double(arguments[2]) ?? 3600 : 3600
    section("M4-12 演练采集（\(Int(seconds))s）——请按轮播方案操作")
    let shim3 = MediaRemoteShim()
    print("adapter 探针: \(shim3.isAvailable ? "OK" : "FAILED")")
    fflush(stdout)

    final class DriftState: @unchecked Sendable {
        var baseElapsed: Double?
        var baseWall: TimeInterval?
        var lastElapsed: Double?
        var lastWall: TimeInterval?
        var worst: Double = 0
        var lastCumulative: Double?
    }
    let drift = DriftState()
    let state = WatchState()

    let stopListener = shim3.startNowPlayingListener { payload in
        let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
        let title = payload["title"] as? String ?? ""
        let artist = payload["artist"] as? String ?? ""
        let elapsed = (payload["elapsedMs"] as? Double) ?? 0
        if title != state.lastTitle {
            let pid = payload["pid"] as? Int ?? -1
            print("[\(stamp)] MR track: \(title) — \(artist)  [pid=\(pid)]")
            fflush(stdout)
            state.lastTitle = title
        }
        let now = Date().timeIntervalSince1970
        if drift.baseWall == nil {
            drift.baseWall = now
            drift.baseElapsed = elapsed
            print(String(format: "[%.3f] DRIFT base elapsed=%.0f", now, elapsed))
            fflush(stdout)
        } else if let lw = drift.lastWall, let le = drift.lastElapsed,
                  let bw = drift.baseWall, let be = drift.baseElapsed
        {
            let interval = (elapsed - le) - (now - lw) * 1000
            if abs(interval) < 5000 {
                drift.worst = max(drift.worst, abs(interval))
                let cumulative = (elapsed - be) - (now - bw) * 1000
                print(String(format: "DRIFTSAMPLE %.3f elapsed=%.0f cum=%.1fms", now, elapsed, cumulative))
                fflush(stdout)
                drift.lastCumulative = cumulative
            } else {
                drift.baseWall = now
                drift.baseElapsed = elapsed
                print(String(format: "[%.3f] GAP 重置基准（跳变）", now))
                fflush(stdout)
            }
        }
        drift.lastWall = now
        drift.lastElapsed = elapsed
    }

    // 直连对照（2s 轮询）。
    let spotify = SpotifySource()
    let directTimer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "m412.direct"))
    directTimer.schedule(deadline: .now(), repeating: 2.0)
    directTimer.setEventHandler {
        if let snapshot = spotify.currentSnapshot() {
            let title = snapshot.track?.title ?? ""
            if title != state.lastDirectTitle {
                let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
                print("[\(stamp)] DIRECT track: \(title)")
                fflush(stdout)
                state.lastDirectTitle = title
            }
        }
    }
    directTimer.resume()

    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    directTimer.cancel()
    stopListener()
    if let bw = drift.baseWall, let lastCum = drift.lastCumulative {
        let wall = Date().timeIntervalSince1970
        print(String(format: "M4-12 漂移汇总: 窗口 %.0fs 末累计 %.1fms 区间最大 %.1fms", wall - bw, lastCum, drift.worst))
    }
    print("m412 采集结束")
}

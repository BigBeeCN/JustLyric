import Foundation

/// MediaRemote 读取垫片（S7 D37 形态）。
///
/// > Important 红线（[红线-P2]）：**MediaRemote 符号单点隔离于 `MediaRemoteAdapterCore/adapter.c`**
/// > （QA 符号扫描项随迁）；本文件为宿主客户端，零 MediaRemote 符号。
/// >
/// > 背景（Spike-3 根因）：mediaremoted 仅对 **Apple 平台二进制宿主**放行（信任位 512）；
/// > 读数经 perl/DynaLoader 宿主加载 adapter dylib（`adapter-host.pl`），JSON over stdout。
/// >
/// > 强制（D37 #2/#3/#4）：宿主抽象 `AdapterHost`（perl 弃用对冲，备选 Widget/JXA）；
/// > 降级链保留（直连 > 窗口标题，宿主不可用自动回退——本类 `isAvailable=false` 即触发）；
/// > 常驻流式、单查 <100ms（缓存）、崩溃自动重启（≤1 次/分钟）。
public final class MediaRemoteShim: @unchecked Sendable {
    /// 默认 adapter dylib 解析（开发态 .build / 发行态 bundle Resources）。
    public static var defaultPath: String {
        if let env = ProcessInfo.processInfo.environment["MEDIAREMOTE_ADAPTER_DYLIB"] {
            return env
        }
        let fm = FileManager.default
        let candidates = [
            "libMediaRemoteAdapterLib.dylib",
            "MediaRemoteAdapterLib.dylib",
        ]
        for dir in [".build/debug", ".build/release", "Resources"] {
            for name in candidates {
                let path = dir + "/" + name
                if fm.fileExists(atPath: path) {
                    return path
                }
            }
        }
        return "libMediaRemoteAdapterLib.dylib"
    }

    private let host: PerlAdapterHost
    private let lock = NSLock()
    private var healthy: Bool

    /// 探测结果：宿主可用（存在→加载→探针应答）且未降级。
    public var isAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return healthy
    }

    /// 创建垫片。
    /// - Parameter path: adapter dylib 路径（测试可注入无效路径演练降级）。
    public init(path: String = MediaRemoteShim.defaultPath) {
        let script = ProcessInfo.processInfo.environment["MEDIAREMOTE_ADAPTER_HOST"]
            ?? Bundle.main.path(forResource: "adapter-host", ofType: "pl")
            ?? "Sources/MediaSession/MediaRemoteAdapter/adapter-host.pl"
        let adapterHost = PerlAdapterHost(dylibPath: path, hostScriptPath: script)
        host = adapterHost

        // 启动能力探测（D37 #2：存在→加载→探针应答）。
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        Task {
            ok = await adapterHost.probe()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5)
        healthy = ok
        if ok {
            Task { _ = await host.start() }
        }
    }

    /// 解析状态（探针报告，QA 扫描项随迁后唯一出口）。
    public func symbolStatus() -> [(name: String, resolved: Bool)] {
        [("adapter(probe)", isAvailable)]
    }

    /// 当前播放信息（读流缓存，单查 <100ms，D37 #4）。
    /// - Parameter timeout: 兼容参数（缓存读无等待）。
    /// - Returns: 归一化信息（title/artist/album/duration/elapsed）。
    public func nowPlayingInfo(timeout: TimeInterval = 2) -> [String: Any]? {
        guard isAvailable, let state = host.latestState else { return nil }
        var result: [String: Any] = [:]
        for key in ["title", "artist", "album"] {
            if let value = state[key] as? String {
                result[key] = value
            }
        }
        if let durationMs = state["durationMs"] as? Double {
            result["duration"] = durationMs / 1000
        }
        if let elapsedMs = state["elapsedMs"] as? Double {
            result["elapsedTime"] = elapsedMs / 1000
        }
        return result.isEmpty ? nil : result
    }

    /// 当前播放应用 PID（M4-12 集成回填；宿主载荷未含时为 nil）。
    public func nowPlayingApplicationPID(timeout: TimeInterval = 2) -> Int32? {
        (host.latestState?["pid"] as? NSNumber).map { Int32(truncating: $0) }
    }

    /// 是否正在播放（M4-12 集成回填）。
    public func isNowPlaying(timeout: TimeInterval = 2) -> Bool? {
        host.latestState?["playing"] as? Bool
    }

    /// 注册/注销（宿主常驻模式下为语义占位；保持 API 兼容）。
    public func registerForNowPlayingNotifications() {}
    /// 见 ``registerForNowPlayingNotifications()``。
    public func unregisterForNowPlayingNotifications() {}

    /// 订阅 now playing 状态流（D37 JSON lines 流式）。
    /// - Parameter handler: 载荷回调。
    /// - Returns: 停止函数。
    public func startNowPlayingListener(
        handler: @escaping @Sendable ([String: Any]) -> Void
    ) -> @Sendable () -> Void {
        guard isAvailable else { return {} }
        let stream = host.states
        let task = Task {
            for await payload in stream {
                handler(payload)
            }
        }
        return { task.cancel() }
    }
}

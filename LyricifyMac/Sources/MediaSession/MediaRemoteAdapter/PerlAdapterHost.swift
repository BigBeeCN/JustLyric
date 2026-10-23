import Foundation

/// perl/DynaLoader 宿主实现（S7 D37：Apple 平台二进制宿主 + JSON over stdout）。
///
/// 强制（D37 #4）：常驻、JSON lines 流式、单查 <100ms（缓存）、崩溃自动重启（≤1 次/分钟防抖）。
public final class PerlAdapterHost: AdapterHost, @unchecked Sendable {
    /// 重启防抖窗（秒）：≤1 次/分钟（D37 #4）。
    static let restartDebounceSeconds: TimeInterval = 60

    private let dylibPath: String
    private let hostScriptPath: String
    private let lock = NSLock()
    private var process: Process?
    private var cached: [String: Any]?
    private var continuations: [UUID: AsyncStream<[String: Any]>.Continuation] = [:]
    private var lastRestart: TimeInterval = -.infinity
    private var readQueue = DispatchQueue(label: "com.lyricifymac.adapterhost")

    /// 创建宿主。
    /// - Parameters:
    ///   - dylibPath: adapter dylib 路径。
    ///   - hostScriptPath: perl 宿主脚本路径。
    public init(dylibPath: String, hostScriptPath: String) {
        // 宿主 dlopen 拒绝相对路径（hardened）——一律绝对化。
        self.dylibPath = (dylibPath as NSString).isAbsolutePath
            ? dylibPath
            : FileManager.default.currentDirectoryPath + "/" + dylibPath
        self.hostScriptPath = (hostScriptPath as NSString).isAbsolutePath
            ? hostScriptPath
            : FileManager.default.currentDirectoryPath + "/" + hostScriptPath
    }

    deinit {
        stop()
    }

    /// 同步锁封装（async 上下文禁直调 NSLock——Swift 6 弃用警告）。
    @discardableResult
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    public var latestState: [String: Any]? {
        withLock { cached }
    }

    public var states: AsyncStream<[String: Any]> {
        let id = UUID()
        return AsyncStream { continuation in
            self.lock.lock()
            self.continuations[id] = continuation
            self.lock.unlock()
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
        }
    }

    public func probe() async -> Bool {
        // 存在→加载→探针应答（D37 #2）。
        guard FileManager.default.fileExists(atPath: dylibPath),
              FileManager.default.fileExists(atPath: hostScriptPath) else { return false }
        let output = runOneShot(command: "probe")
        return output?.contains("\"ok\":true") == true
    }

    public func start() async -> Bool {
        let running = withLock { self.process?.isRunning == true }
        if running {
            return true
        }

        let now = Date().timeIntervalSince1970
        let allowed = withLock { () -> Bool in
            guard now - lastRestart >= Self.restartDebounceSeconds else { return false }
            lastRestart = now
            return true
        }
        guard allowed else { return false }

        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        child.arguments = [hostScriptPath, dylibPath, "loop"]
        let pipe = Pipe()
        child.standardOutput = pipe
        child.standardError = FileHandle.nullDevice

        do {
            try child.run()
        } catch {
            return false
        }
        withLock { self.process = child }

        let handle = pipe.fileHandleForReading
        readQueue.async { [weak self] in
            var buffer = Data()
            while child.isRunning || !buffer.isEmpty {
                let chunk = handle.availableData
                if chunk.isEmpty {
                    break
                }
                buffer.append(chunk)
                while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                    let lineData = buffer[buffer.startIndex ..< newline]
                    buffer = Data(buffer[buffer.index(after: newline)...])
                    if let line = String(data: lineData, encoding: .utf8),
                       let payload = AdapterPayload.parse(line),
                       payload["type"] as? String == "state"
                    {
                        self?.publish(payload)
                    }
                }
            }
            self?.handleTermination()
        }
        return true
    }

    public func stop() {
        withLock {
            process?.terminate()
            process = nil
        }
    }

    // MARK: - 私有

    private func publish(_ payload: [String: Any]) {
        let continuationsSnapshot = withLock { () -> [AsyncStream<[String: Any]>.Continuation] in
            cached = payload
            return Array(continuations.values)
        }
        for continuation in continuationsSnapshot {
            continuation.yield(payload)
        }
    }

    private func removeContinuation(_ id: UUID) {
        withLock { continuations.removeValue(forKey: id) }
    }

    /// 崩溃自动重启（≤1 次/分钟防抖，D37 #4）。
    private func handleTermination() {
        withLock { process = nil }
        Task { [weak self] in
            guard let self else { return }
            _ = await start() // start 内部防抖
        }
    }

    private func runOneShot(command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [hostScriptPath, dylibPath, command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}

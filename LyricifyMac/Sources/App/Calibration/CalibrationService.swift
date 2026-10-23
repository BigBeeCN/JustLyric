import Foundation
import MediaSession

/// 校准生产化服务（D46 #3：跟拍测试器 → 四层求和写入设置；A5 正值=延后）。
///
/// 替代开发 shim（预览窗环境变量旁路本波次停用，发版检查项清理归零）。
public final class CalibrationService: @unchecked Sendable {
    /// 设置存储。
    public let settingsStore: SettingsStore
    /// 点拍缓冲（用户每次对拍录入）。
    private var taps: [Int] = []
    private let lock = NSLock()

    /// 创建服务。
    /// - Parameter settingsStore: 设置存储。
    public init(settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
    }

    /// 录入一次点拍（正=比参考拍晚，歌词应延后——A5）。
    /// - Parameter offsetMs: 偏差毫秒。
    public func recordTap(offsetMs: Int) {
        lock.lock()
        taps.append(offsetMs)
        lock.unlock()
    }

    /// 当前点拍均值（nil=未采样）。
    public var sampledOffsetMs: Int? {
        lock.lock()
        defer { lock.unlock() }
        guard !taps.isEmpty else { return nil }
        return taps.reduce(0, +) / taps.count
    }

    /// 提交全局延迟（写入 `latency.device_latency`，A5 正值=延后）。
    /// - Returns: 写入值。
    @discardableResult
    public func commitToGlobal() throws -> Int {
        let value = sampledOffsetMs ?? 0
        var settings = settingsStore.load()
        settings.latency.deviceLatency = value
        try settingsStore.save(settings)
        lock.lock()
        taps = []
        lock.unlock()
        return value
    }

    /// 提交每设备延迟（写入 `latency.device_latency_per_device`）。
    /// - Parameters:
    ///   - deviceUID: 设备 UID。
    ///   - deviceType: 设备类型字符串。
    /// - Returns: 写入值。
    @discardableResult
    public func commitToDevice(deviceUID: String, deviceType: String = "unknown") throws -> Int {
        let value = sampledOffsetMs ?? 0
        var settings = settingsStore.load()
        settings.latency.deviceLatencyPerDevice.append(
            DeviceLatencyEntry(id: deviceUID, deviceType: deviceType, latency: value)
        )
        try settingsStore.save(settings)
        lock.lock()
        taps = []
        lock.unlock()
        return value
    }

    /// 生效偏移（四层求和，S3 §5；显示面统一入口——预览/桌面/全屏）。
    /// - Parameters:
    ///   - sourceID: 命中源标识。
    ///   - bundleID: 来源 app。
    /// - Returns: 生效偏移（A5 正值=延后）。
    public func effectiveOffsetMs(sourceID: String?, bundleID: String?) -> Int {
        let settings = settingsStore.load()
        var perDevice: [String: DeviceLatency] = [:]
        for entry in settings.latency.deviceLatencyPerDevice {
            perDevice[entry.id] = DeviceLatency(
                latencyMs: entry.latency,
                deviceType: AudioDeviceType(rawValue: entry.deviceType) ?? .unknown
            )
        }
        let config = LatencyConfig(
            globalMs: settings.latency.deviceLatency,
            perDevice: perDevice,
            perSource: settings.sources.lyricsLatency,
            perApp: Dictionary(
                uniqueKeysWithValues: settings.sessions.map { ($0.id, $0.sessionLatency) }
            )
        )
        return config.effectiveOffsetMs(
            currentOutputDeviceUID: nil,
            hitSource: sourceID,
            bundleID: bundleID
        )
    }
}

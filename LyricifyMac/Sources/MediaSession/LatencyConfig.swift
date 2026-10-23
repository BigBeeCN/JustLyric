import Foundation

/// 音频输出设备类型（S3 §5）。
public enum AudioDeviceType: String, Sendable, Equatable {
    /// 蓝牙。
    case bluetooth
    /// 扬声器。
    case speaker
    /// 耳机（有线）。
    case headphone
    /// 未知。
    case unknown
}

/// 设备延迟（S3 §5：`device_latency_per_device[{id,device_type,latency}]`）。
public struct DeviceLatency: Sendable, Equatable {
    /// 延迟（毫秒，正值=歌词延后）。
    public var latencyMs: Int
    /// 设备类型。
    public var deviceType: AudioDeviceType

    /// 创建设备延迟。
    /// - Parameters:
    ///   - latencyMs: 延迟毫秒。
    ///   - deviceType: 设备类型。
    public init(latencyMs: Int, deviceType: AudioDeviceType) {
        self.latencyMs = latencyMs
        self.deviceType = deviceType
    }
}

/// 四层延迟配置（S3 §5；S7 D29 #1：四层同 A5 正值=延后，生效偏移=求和可为负）。
///
/// 生效偏移 = `global + perDevice[currentOutput] + perSource[hitSource] + perApp[bundleID]`。
public struct LatencyConfig: Sendable, Equatable {
    /// 全局延迟（S5 `device_latency`）。
    public var globalMs: Int
    /// 每设备延迟（key = AudioDevice UID）。
    public var perDevice: [String: DeviceLatency]
    /// 每源延迟（key = 源标识；依赖方向下以 String 键承载，实现级记录）。
    public var perSource: [String: Int]
    /// 每 app 延迟（key = bundle id）。
    public var perApp: [String: Int]

    /// 创建延迟配置。
    /// - Parameters:
    ///   - globalMs: 全局延迟。
    ///   - perDevice: 每设备延迟。
    ///   - perSource: 每源延迟。
    ///   - perApp: 每 app 延迟。
    public init(
        globalMs: Int = 0,
        perDevice: [String: DeviceLatency] = [:],
        perSource: [String: Int] = [:],
        perApp: [String: Int] = [:]
    ) {
        self.globalMs = globalMs
        self.perDevice = perDevice
        self.perSource = perSource
        self.perApp = perApp
    }

    /// 生效偏移（S3 §5 求和；缺失层计 0；可为负）。
    /// - Parameters:
    ///   - currentOutputDeviceUID: 当前输出设备 UID。
    ///   - hitSource: 命中源标识。
    ///   - bundleID: 来源 app bundle id。
    /// - Returns: 毫秒偏移（正值=歌词延后）。
    public func effectiveOffsetMs(
        currentOutputDeviceUID: String?,
        hitSource: String?,
        bundleID: String?
    ) -> Int {
        var offset = globalMs
        if let uid = currentOutputDeviceUID, let device = perDevice[uid] {
            offset += device.latencyMs
        }
        if let source = hitSource, let value = perSource[source] {
            offset += value
        }
        if let bundleID, let value = perApp[bundleID] {
            offset += value
        }
        return offset
    }
}

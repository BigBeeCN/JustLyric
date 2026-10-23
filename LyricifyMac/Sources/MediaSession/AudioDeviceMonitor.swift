import CoreAudio
import Foundation

/// CoreAudio 设备探测抽象（测试可注入 stub）。
public protocol AudioDeviceInspecting: Sendable {
    /// 默认输出设备 UID。
    func defaultOutputDeviceUID() -> String?
    /// 指定设备是否蓝牙传输。
    /// - Parameter uid: 设备 UID。
    /// - Returns: 蓝牙时为 `true`。
    func isBluetoothOutput(uid: String?) -> Bool
}

/// CoreAudio 实现（S3 §5：`kAudioDevicePropertyTransportType == kAudioDeviceTransportTypeBluetooth`）。
public struct CoreAudioDeviceInspector: AudioDeviceInspecting {
    /// 创建探测器。
    public init() {}

    public func defaultOutputDeviceUID() -> String? {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        ) == noErr else { return nil }

        var uidRef: Unmanaged<CFString>?
        var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            deviceID, &uidAddress, 0, nil, &uidSize, &uidRef
        ) == noErr else {
            return nil
        }
        return uidRef?.takeUnretainedValue() as String?
    }

    public func isBluetoothOutput(uid: String?) -> Bool {
        // 仅对默认输出设备判传输类型（uid 用于确认身份）。
        guard let uid, uid == defaultOutputDeviceUID() else { return false }
        // 按 UID 找设备。
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        ) == noErr else { return false }

        var transport: UInt32 = 0
        var transportSize = UInt32(MemoryLayout<UInt32>.size)
        var transportAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            deviceID, &transportAddress, 0, nil, &transportSize, &transport
        ) == noErr else { return false }
        return transport == kAudioDeviceTransportTypeBluetooth
    }
}

/// 输出设备监视（S3 §5；S7 D29 #1：+150ms 仅 UI 预填，用户确认后写入，不自动生效）。
public struct AudioDeviceMonitor: Sendable {
    /// 蓝牙建议延迟（毫秒；仅预填）。
    public static let bluetoothSuggestionMs = 150

    private let inspector: any AudioDeviceInspecting

    /// 创建监视器。
    /// - Parameter inspector: 设备探测器。
    public init(inspector: any AudioDeviceInspecting = CoreAudioDeviceInspector()) {
        self.inspector = inspector
    }

    /// 当前输出是否蓝牙。
    public func isBluetoothOutput() -> Bool {
        inspector.isBluetoothOutput(uid: inspector.defaultOutputDeviceUID())
    }

    /// 当前输出设备 UID。
    public func currentOutputDeviceUID() -> String? {
        inspector.defaultOutputDeviceUID()
    }

    /// 延迟建议（**仅 UI 预填**，D29 #1：不自动写入配置）。
    /// - Returns: 建议毫秒；非蓝牙为 `nil`。
    public func latencySuggestion() -> Int? {
        isBluetoothOutput() ? Self.bluetoothSuggestionMs : nil
    }

    /// 应用建议到配置（用户确认后调用；未确认不得调用）。
    /// - Parameters:
    ///   - config: 延迟配置（写入 perDevice）。
    ///   - deviceType: 设备类型。
    public func confirmSuggestion(into config: inout LatencyConfig, deviceType: AudioDeviceType = .bluetooth) {
        guard let uid = currentOutputDeviceUID(), let suggestion = latencySuggestion() else { return }
        config.perDevice[uid] = DeviceLatency(latencyMs: suggestion, deviceType: deviceType)
    }
}

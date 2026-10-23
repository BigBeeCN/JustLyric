import Foundation
import LyricsCore
import MediaSession
import Sources

/// per-app 会话设置视图模型（S3 §4/T2.24 接线；M4-06）。
///
/// 职责：kind 判定、未知 app 询问流程、`sessions[]` 持久化桥接（SessionEntry）。
public struct SessionSettingsViewModel: Equatable, Sendable {
    /// 会话条目表（bundle id → 条目）。
    public var entries: [String: SessionEntry]

    /// 创建视图模型。
    /// - Parameter entries: 条目表。
    public init(entries: [String: SessionEntry] = [:]) {
        self.entries = entries
    }

    /// 决策（S3 §4：未知 app 首次询问）。
    /// - Parameters:
    ///   - bundleID: bundle id。
    ///   - kind: 分类（`SessionRules.kind`）。
    /// - Returns: `nil` = 需询问。
    public func decision(bundleID: String, kind: SessionKind) -> Bool? {
        if let entry = entries[bundleID] {
            return entry.isEnabled
        }
        if kind == .unknown {
            return nil
        }
        return SessionRules.defaultEnabled(for: kind)
    }

    /// 记住用户选择（询问后写回条目表，M4-06）。
    /// - Parameters:
    ///   - bundleID: bundle id。
    ///   - enabled: 启用。
    public mutating func remember(bundleID: String, enabled: Bool) {
        var entry = entries[bundleID] ?? SessionEntry(id: bundleID)
        entry.isEnabled = enabled
        entry.kind = SessionRules.kind(forBundleID: bundleID).rawValue
        entries[bundleID] = entry
    }
}

/// 延迟校准视图模型（S3 §5/T2.25 接线；M4-07）。
///
/// 蓝牙 +150ms 仅预填（D29 #1：确认后写入）；跟拍测试器（点拍校准）。
public struct LatencyCalibrator: Sendable {
    /// 蓝牙建议（D29 #1）。
    public static let bluetoothSuggestionMs = AudioDeviceMonitor.bluetoothSuggestionMs

    /// 配置。
    public var config: LatencyConfig
    /// 预填建议（未确认值，D29 #1）。
    public private(set) var pendingSuggestion: Int?

    /// 创建校准器。
    /// - Parameter config: 配置。
    public init(config: LatencyConfig = LatencyConfig()) {
        self.config = config
    }

    /// 载入蓝牙建议（仅预填，不写入——D29 #1）。
    /// - Parameter isBluetooth: 当前输出蓝牙。
    public mutating func loadSuggestion(isBluetooth: Bool) {
        pendingSuggestion = isBluetooth ? Self.bluetoothSuggestionMs : nil
    }

    /// 用户确认写入（D29 #1：确认后才生效）。
    /// - Parameter deviceUID: 设备 UID。
    public mutating func confirmSuggestion(deviceUID: String) {
        guard let suggestion = pendingSuggestion else { return }
        config.perDevice[deviceUID] = DeviceLatency(
            latencyMs: suggestion,
            deviceType: .bluetooth
        )
        pendingSuggestion = nil
    }

    /// 跟拍测试器：点拍序列 → 平均偏差（ms；正=歌词应延后）。
    /// - Parameters:
    ///   - tapOffsetsMs: 每拍偏差（用户实际点拍时刻 − 参考拍点）。
    /// - Returns: 平均偏差；空序列为 nil。
    public static func tapCalibrationOffset(tapOffsetsMs: [Int]) -> Int? {
        guard !tapOffsetsMs.isEmpty else { return nil }
        return tapOffsetsMs.reduce(0, +) / tapOffsetsMs.count
    }
}

/// 源/账号设置视图模型（S5 §1.1；M4-08）。
public struct SourceSettingsViewModel: Sendable {
    /// 源设置。
    public var settings: SourcesSettings

    /// 创建视图模型。
    /// - Parameter settings: 源设置。
    public init(settings: SourcesSettings = SourcesSettings()) {
        self.settings = settings
    }

    /// 转 `SourcePreferences`（S2 §4 编排入参）。
    /// - Parameter minMatch: 最低档。
    /// - Returns: 偏好。
    public func preferences(minMatch: MatchLevel) -> SourcePreferences {
        let disabled = Set(settings.lyricsSourcesDisabled.compactMap(SourceID.init(identifier:)))
        var latency: [SourceID: Int] = [:]
        for (key, value) in settings.lyricsLatency {
            if let id = SourceID(identifier: key) {
                latency[id] = value
            }
        }
        return SourcePreferences(
            order: settings.lyricsSources.compactMap(SourceID.init(identifier:)),
            minMatch: minMatch,
            disabled: disabled,
            lyricsLatencyBySource: latency
        )
    }

    /// LocalFiles 目录合法性（M4-08）。
    /// - Parameter path: 目录路径。
    /// - Returns: 非空且可解析。
    public func isValidDirectory(_ path: String) -> Bool {
        !path.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

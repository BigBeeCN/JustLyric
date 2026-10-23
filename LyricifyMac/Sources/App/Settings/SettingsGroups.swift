import Foundation

// MARK: - latency（S3 §5 直通）

public struct DeviceLatencyEntry: Codable, Equatable, Sendable {
    /// 设备 UID。
    public var id: String
    /// 设备类型（bluetooth/speaker/headphone/unknown）。
    public var deviceType: String
    /// 延迟（ms，正值=延后）。
    public var latency: Int

    public init(id: String, deviceType: String, latency: Int) {
        self.id = id
        self.deviceType = deviceType
        self.latency = latency
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        deviceType = try c.decodeIfPresent(String.self, forKey: .deviceType) ?? "unknown"
        latency = try c.decodeIfPresent(Int.self, forKey: .latency) ?? 0
    }
}

public struct LatencySettings: Codable, Equatable, Sendable {
    /// 全局延迟（`device_latency`）。
    public var deviceLatency: Int
    /// 每设备延迟。
    public var deviceLatencyPerDevice: [DeviceLatencyEntry]

    public init(deviceLatency: Int = 0, deviceLatencyPerDevice: [DeviceLatencyEntry] = []) {
        self.deviceLatency = deviceLatency
        self.deviceLatencyPerDevice = deviceLatencyPerDevice
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deviceLatency = try c.decodeIfPresent(Int.self, forKey: .deviceLatency) ?? 0
        deviceLatencyPerDevice = try c.decodeIfPresent(
            [DeviceLatencyEntry].self, forKey: .deviceLatencyPerDevice
        ) ?? []
    }
}

// MARK: - sources（S5 §1.1；[红线-P1] MUT 仅 Keychain 指针）

public struct SourcesSettings: Codable, Equatable, Sendable {
    /// 源顺序（`lyrics_sources`）。
    public var lyricsSources: [String]
    /// 禁用源（`lyrics_sources_disabled`）。
    public var lyricsSourcesDisabled: [String]
    /// 源延迟（`lyrics_latency`，正值=延后）。
    public var lyricsLatency: [String: Int]
    /// LRCLIB 开关。
    public var lrclibEnabled: Bool
    /// Apple Music 开关。
    public var appleMusicEnabled: Bool
    /// MUT 已存 Keychain 标志（**真值仅存 Keychain**，此处为指针位，[红线-P1]）。
    public var appleMusicMediaUserTokenEncrypted: Bool
    /// 本地文件开关。
    public var localFilesEnabled: Bool
    /// 本地目录列表。
    public var localFilesPaths: [String]

    public init() {
        lyricsSources = ["lrclib", "apple_ttml", "local_files"]
        lyricsSourcesDisabled = []
        lyricsLatency = [:]
        lrclibEnabled = true
        appleMusicEnabled = false
        appleMusicMediaUserTokenEncrypted = false
        localFilesEnabled = false
        localFilesPaths = []
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lyricsSources = try c.decodeIfPresent([String].self, forKey: .lyricsSources)
            ?? ["lrclib", "apple_ttml", "local_files"]
        lyricsSourcesDisabled = try c.decodeIfPresent([String].self, forKey: .lyricsSourcesDisabled) ?? []
        lyricsLatency = try c.decodeIfPresent([String: Int].self, forKey: .lyricsLatency) ?? [:]
        lrclibEnabled = try c.decodeIfPresent(Bool.self, forKey: .lrclibEnabled) ?? true
        appleMusicEnabled = try c.decodeIfPresent(Bool.self, forKey: .appleMusicEnabled) ?? false
        appleMusicMediaUserTokenEncrypted = try c.decodeIfPresent(
            Bool.self, forKey: .appleMusicMediaUserTokenEncrypted
        ) ?? false
        localFilesEnabled = try c.decodeIfPresent(Bool.self, forKey: .localFilesEnabled) ?? false
        localFilesPaths = try c.decodeIfPresent([String].self, forKey: .localFilesPaths) ?? []
    }
}

// MARK: - sessions（T2.24 接线）

public struct SessionEntry: Codable, Equatable, Sendable {
    /// bundle id。
    public var id: String
    /// 启用（`IsEnabledByUser`）。
    public var isEnabled: Bool
    /// 会话延迟（ms）。
    public var sessionLatency: Int
    /// 强制内部时钟（`is_force_use_internal_timer`）。
    public var isForceUseInternalTimer: Bool
    /// 取词开关（`is_lyrics_enabled`）。
    public var isLyricsEnabled: Bool
    /// 分类（musicApp/podcast/video/browser/game/im/unknown）。
    public var kind: String

    public init(id: String) {
        self.id = id
        isEnabled = false
        sessionLatency = 0
        isForceUseInternalTimer = false
        isLyricsEnabled = true
        kind = "unknown"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        sessionLatency = try c.decodeIfPresent(Int.self, forKey: .sessionLatency) ?? 0
        isForceUseInternalTimer = try c.decodeIfPresent(Bool.self, forKey: .isForceUseInternalTimer) ?? false
        isLyricsEnabled = try c.decodeIfPresent(Bool.self, forKey: .isLyricsEnabled) ?? true
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "unknown"
    }
}

// MARK: - island（键位预留组，D39）

public struct IslandSettings: Codable, Equatable, Sendable {
    /// 停靠边（`island.dock_edge`，D39 四缘增强键位预留；v1 默认 top）。
    public var dockEdge: String

    public init(dockEdge: String = "top") {
        self.dockEdge = dockEdge
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dockEdge = try c.decodeIfPresent(String.self, forKey: .dockEdge) ?? "top"
    }
}

// MARK: - 根模型

/// 设置文件根（S5 §1：15 分组；`version` + 迁移器，D35 ⭐）。
public struct SettingsFile: Codable, Equatable {
    /// schema 版本。
    public var version: Int
    /// general。
    public var general: GeneralSettings
    /// lyrics。
    public var lyrics: LyricsSettings
    /// karaoke。
    public var karaoke: KaraokeSettings
    /// desktop_lyrics。
    public var desktopLyrics: DesktopLyricsSettings
    /// latency。
    public var latency: LatencySettings
    /// sources。
    public var sources: SourcesSettings
    /// island（D39 键位预留）。
    public var island: IslandSettings
    /// sessions。
    public var sessions: [SessionEntry]

    public init() {
        version = SettingsMigrator.currentVersion
        general = GeneralSettings()
        lyrics = LyricsSettings()
        karaoke = KaraokeSettings()
        desktopLyrics = DesktopLyricsSettings()
        latency = LatencySettings()
        sources = SourcesSettings()
        island = IslandSettings()
        sessions = []
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
        general = try c.decodeIfPresent(GeneralSettings.self, forKey: .general) ?? GeneralSettings()
        lyrics = try c.decodeIfPresent(LyricsSettings.self, forKey: .lyrics) ?? LyricsSettings()
        karaoke = try c.decodeIfPresent(KaraokeSettings.self, forKey: .karaoke) ?? KaraokeSettings()
        desktopLyrics = try c.decodeIfPresent(
            DesktopLyricsSettings.self, forKey: .desktopLyrics
        ) ?? DesktopLyricsSettings()
        latency = try c.decodeIfPresent(LatencySettings.self, forKey: .latency) ?? LatencySettings()
        sources = try c.decodeIfPresent(SourcesSettings.self, forKey: .sources) ?? SourcesSettings()
        island = try c.decodeIfPresent(IslandSettings.self, forKey: .island) ?? IslandSettings()
        sessions = try c.decodeIfPresent([SessionEntry].self, forKey: .sessions) ?? []
    }
}

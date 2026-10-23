/// Spotify `syncType` 映射（S7 D19 定案；目标枚举落点 Q15 待批）。
public enum SpotifySyncType: String, Codable, Sendable {
    /// 无同步。
    case unsynced = "UNSYNCED"
    /// 行级同步。
    case lineSynced = "LINE_SYNCED"
    /// 逐字同步。
    case syllableSynced = "SYLLABLE_SYNCED"
    /// 其他/未知。
    case unknown = "UNKNOWN"

    /// 从 API 字符串映射（其他值一律 `.unknown`，D19）。
    public init(apiValue: String) {
        self = SpotifySyncType(rawValue: apiValue) ?? .unknown
    }
}

/// Spotify 备选语言文本（D13 形状；D19：备选语言文本，非背景人声）。
public struct SpotifyAlternative: Codable, Equatable, Sendable {
    /// 语言标签。
    public var language: String
    /// 备选语言行文本数组。
    public var lines: [String]
    /// 是否 RTL 语言。
    public var isRtlLanguage: Bool

    /// 创建备选语言文本。
    /// - Parameters:
    ///   - language: 语言标签。
    ///   - lines: 备选语言行文本数组。
    ///   - isRtlLanguage: 是否 RTL 语言。
    public init(language: String, lines: [String], isRtlLanguage: Bool) {
        self.language = language
        self.lines = lines
        self.isRtlLanguage = isRtlLanguage
    }
}

/// Spotify 附加信息（S7 D19：alternatives 不消费，仅随本结构原样保留）。
public struct SpotifyAdditionalInfo: Codable, Equatable, Sendable {
    /// `syncType` 映射结果（D19）。
    public var syncType: SpotifySyncType
    /// 备选语言文本数组（D13 形状，原样保留）。
    public var alternatives: [SpotifyAlternative]

    /// 创建 Spotify 附加信息。
    /// - Parameters:
    ///   - syncType: `syncType` 映射结果。
    ///   - alternatives: 备选语言文本数组。
    public init(syncType: SpotifySyncType, alternatives: [SpotifyAlternative]) {
        self.syncType = syncType
        self.alternatives = alternatives
    }
}

/// 歌词数据（S1 §1）。
public struct LyricsData: Codable, Sendable {
    /// 歌词行数组。
    public var lines: [LyricsLine]
    /// 同步级别。
    public var syncLevel: SyncLevel
    /// 语言标签。
    public var language: [String]
    /// `[offset:]` 属性（毫秒）。
    public var offsetMs: Int
    /// 标题行数（顶部 "作词/作曲/演唱" 块）。
    public var titleLines: Int
    /// 尾行数。
    public var endingLines: Int
    /// 署名（作词/作曲）。
    public var writer: String?
    /// 是否纯音乐。
    public var isInstrumental: Bool
    /// 文件内元数据（S7 D20：ti/ar/al/length 映射，LocalFiles 匹配线索）。
    public var trackMeta: TrackMeta?
    /// 原始格式类型。
    public var source: LyricsRawType
    /// 原文缓存。
    public var raw: String?
    /// 源附加信息（S7 D19：如 Spotify `alternatives`/`syncType` 原样保留，不映射行字段）。
    public var additionalInfo: SpotifyAdditionalInfo?
    /// endMs 推定行数标记（S7 D49；0/nil=无推定）。
    public var inferredSpans: Int?

    /// 创建歌词数据。
    /// - Parameters:
    ///   - lines: 歌词行数组。
    ///   - syncLevel: 同步级别。
    ///   - language: 语言标签。
    ///   - offsetMs: 时间偏移（毫秒）。
    ///   - titleLines: 标题行数。
    ///   - endingLines: 尾行数。
    ///   - writer: 署名，可选。
    ///   - isInstrumental: 是否纯音乐。
    ///   - trackMeta: 文件内元数据，可选（S7 D20）。
    ///   - source: 原始格式类型。
    ///   - raw: 原文缓存，可选。
    ///   - additionalInfo: 源附加信息，可选（S7 D19）。
    public init(
        lines: [LyricsLine] = [],
        syncLevel: SyncLevel = .lineSynced,
        language: [String] = [],
        offsetMs: Int = 0,
        titleLines: Int = 0,
        endingLines: Int = 0,
        writer: String? = nil,
        isInstrumental: Bool = false,
        trackMeta: TrackMeta? = nil,
        source: LyricsRawType = .unknown,
        raw: String? = nil,
        additionalInfo: SpotifyAdditionalInfo? = nil,
        inferredSpans: Int? = nil
    ) {
        self.lines = lines
        self.syncLevel = syncLevel
        self.language = language
        self.offsetMs = offsetMs
        self.titleLines = titleLines
        self.endingLines = endingLines
        self.writer = writer
        self.isInstrumental = isInstrumental
        self.trackMeta = trackMeta
        self.source = source
        self.raw = raw
        self.additionalInfo = additionalInfo
        self.inferredSpans = inferredSpans
    }
}

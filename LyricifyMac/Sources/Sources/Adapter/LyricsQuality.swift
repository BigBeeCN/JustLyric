/// 歌词质量档（S7 D25 #2：降级链各级结果 quality 标记；亦作候选质量提示）。
public enum LyricsQuality: Int, Codable, Sendable, Comparable {
    /// 未知。
    case unknown = 0
    /// 纯文本（plainLyrics）。
    case plain = 1
    /// 行级同步。
    case lineSynced = 2
    /// 逐字同步。
    case syllableSynced = 3

    public static func < (lhs: LyricsQuality, rhs: LyricsQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

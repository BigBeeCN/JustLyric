/// 维度匹配档位（S2 §2.1：Perfect=7 VeryHigh=6 High=5 Medium=4 Low=2 NoMatch=0）。
public enum MatchLevel: Int, Codable, Sendable, Comparable {
    /// 无匹配（0）。
    case noMatch = 0
    /// 低（2）。
    case low = 2
    /// 中（4）。
    case medium = 4
    /// 高（5）。
    case high = 5
    /// 很高（6）。
    case veryHigh = 6
    /// 完美（7）。
    case perfect = 7

    public static func < (lhs: MatchLevel, rhs: MatchLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 曲名匹配档位别名（S7 D14）。
public typealias NameMatch = MatchLevel
/// 歌手匹配档位别名（S7 D4/D14）。
public typealias ArtistMatch = MatchLevel
/// 时长匹配档位别名（S7 D14）。
public typealias DurationMatch = MatchLevel

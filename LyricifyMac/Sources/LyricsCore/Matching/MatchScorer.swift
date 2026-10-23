/// 合成打分（S2 §2.5 原公式）。
///
/// ```text
/// score = name + artist + album×0.4 + albumArtist×0.2 + duration     // 每维取 0/2/4/5/6/7
/// base  = 14.0 + (album!=null ? 2.8 : 0) + (albumArtist!=null ? 1.4 : 0) + (duration!=null ? 7.0 : 0)
/// score = score × 25.2 / base
/// ```
public enum MatchScorer {
    /// 合成档位（S2 §2.5：含 PrettyHigh/VeryLow 两个合成档）。
    public enum ScoreTier: String, Codable, Sendable, Comparable {
        /// score > 21。
        case perfect
        /// score > 19。
        case veryHigh
        /// score > 17。
        case high
        /// score > 15。
        case prettyHigh
        /// score > 11。
        case medium
        /// score > 8。
        case low
        /// score > 3。
        case veryLow
        /// else。
        case noMatch

        private var rank: Int {
            switch self {
            case .perfect: 7
            case .veryHigh: 6
            case .high: 5
            case .prettyHigh: 4
            case .medium: 3
            case .low: 2
            case .veryLow: 1
            case .noMatch: 0
            }
        }

        public static func < (lhs: ScoreTier, rhs: ScoreTier) -> Bool {
            lhs.rank < rhs.rank
        }
    }

    /// 维度输入（null 维度得分记 0 且 base 不加权）。
    public struct MatchInput: Sendable {
        /// 曲名维度。
        public var name: NameMatch?
        /// 歌手维度。
        public var artist: ArtistMatch?
        /// 专辑维度（CompareName 结果 ×0.4）。
        public var album: NameMatch?
        /// 专辑艺人维度（CompareArtist 结果 ×0.2）。
        public var albumArtist: ArtistMatch?
        /// 时长维度。
        public var duration: DurationMatch?

        /// 创建维度输入。
        /// - Parameters:
        ///   - name: 曲名维度。
        ///   - artist: 歌手维度。
        ///   - album: 专辑维度。
        ///   - albumArtist: 专辑艺人维度。
        ///   - duration: 时长维度。
        public init(
            name: NameMatch? = nil,
            artist: ArtistMatch? = nil,
            album: NameMatch? = nil,
            albumArtist: ArtistMatch? = nil,
            duration: DurationMatch? = nil
        ) {
            self.name = name
            self.artist = artist
            self.album = album
            self.albumArtist = albumArtist
            self.duration = duration
        }
    }

    /// 合成得分（原公式，S2 §2.5）。
    /// - Parameter input: 维度输入。
    /// - Returns: 归一化得分。
    public static func score(_ input: MatchInput) -> Double {
        let name = Double(input.name?.rawValue ?? 0)
        let artist = Double(input.artist?.rawValue ?? 0)
        let album = Double(input.album?.rawValue ?? 0) * 0.4
        let albumArtist = Double(input.albumArtist?.rawValue ?? 0) * 0.2
        let duration = Double(input.duration?.rawValue ?? 0)

        var base = 14.0
        if input.album != nil {
            base += 2.8
        }
        if input.albumArtist != nil {
            base += 1.4
        }
        if input.duration != nil {
            base += 7.0
        }

        return (name + artist + album + albumArtist + duration) * 25.2 / base
    }

    /// 档位映射（严格大于：`>21 | >19 | >17 | >15 | >11 | >8 | >3 | else`）。
    /// - Parameter score: 合成得分。
    /// - Returns: 档位。
    public static func tier(for score: Double) -> ScoreTier {
        switch score {
        case let value where value > 21: .perfect
        case let value where value > 19: .veryHigh
        case let value where value > 17: .high
        case let value where value > 15: .prettyHigh
        case let value where value > 11: .medium
        case let value where value > 8: .low
        case let value where value > 3: .veryLow
        default: .noMatch
        }
    }
}

/// 多候选排序（S2 §2.5：档位降序 → 源优先级 → offset/逐字能力）。
public struct MatchCandidate: Sendable {
    /// 合成得分。
    public var score: Double
    /// 源优先级（数值小者优先）。
    public var sourcePriority: Int
    /// 候选偏移（毫秒）。
    public var offsetMs: Int
    /// 是否逐字能力。
    public var supportsSyllable: Bool

    /// 创建候选。
    /// - Parameters:
    ///   - score: 合成得分。
    ///   - sourcePriority: 源优先级（数值小者优先）。
    ///   - offsetMs: 候选偏移（毫秒）。
    ///   - supportsSyllable: 是否逐字能力。
    public init(score: Double, sourcePriority: Int, offsetMs: Int, supportsSyllable: Bool) {
        self.score = score
        self.sourcePriority = sourcePriority
        self.offsetMs = offsetMs
        self.supportsSyllable = supportsSyllable
    }
}

/// 候选排序器。
public enum CandidateRanker {
    /// 排序：档位降序 → 源优先级升序 → |offset| 升序 → 逐字能力优先。
    /// - Parameter candidates: 候选数组。
    /// - Returns: 排序后数组。
    public static func rank(_ candidates: [MatchCandidate]) -> [MatchCandidate] {
        candidates.sorted(by: isOrderedBefore)
    }

    /// 按候选键排序任意元素（编排器回映射用）。
    /// - Parameters:
    ///   - items: 元素数组。
    ///   - key: 候选键提取。
    /// - Returns: 排序后数组。
    public static func rank<T>(_ items: [T], by key: (T) -> MatchCandidate) -> [T] {
        items.sorted { isOrderedBefore(key($0), key($1)) }
    }

    /// 比较器（档位↓ → 源优先级↑ → |offset|↑ → 逐字优先）。
    private static func isOrderedBefore(_ lhs: MatchCandidate, _ rhs: MatchCandidate) -> Bool {
        let lhsTier = MatchScorer.tier(for: lhs.score)
        let rhsTier = MatchScorer.tier(for: rhs.score)
        if lhsTier != rhsTier {
            return lhsTier > rhsTier
        }
        if lhs.sourcePriority != rhs.sourcePriority {
            return lhs.sourcePriority < rhs.sourcePriority
        }
        if lhs.offsetMs != rhs.offsetMs {
            return abs(lhs.offsetMs) < abs(rhs.offsetMs)
        }
        return lhs.supportsSyllable && !rhs.supportsSyllable
    }
}

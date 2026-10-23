import LyricsCore

/// 源偏好（S2 §4 编排入参；S5 `sources` 组设置直通）。
public struct SourcePreferences: Sendable {
    /// 用户优先级顺序（数组序即优先级）。
    public var order: [SourceID]
    /// 最低可接受档（首个满足 `minMatch` 的结果先用，S2 §4）。
    public var minMatch: MatchLevel
    /// 禁用源（S5 `lyrics_sources_disabled`）。
    public var disabled: Set<SourceID>
    /// 源延迟（毫秒，S5 `lyrics_latency`；正值=延后，A5）。
    public var lyricsLatencyBySource: [SourceID: Int]

    /// 创建源偏好。
    /// - Parameters:
    ///   - order: 用户优先级顺序。
    ///   - minMatch: 最低可接受档。
    ///   - disabled: 禁用源。
    ///   - lyricsLatencyBySource: 源延迟表。
    public init(
        order: [SourceID],
        minMatch: MatchLevel,
        disabled: Set<SourceID> = [],
        lyricsLatencyBySource: [SourceID: Int] = [:]
    ) {
        self.order = order
        self.minMatch = minMatch
        self.disabled = disabled
        self.lyricsLatencyBySource = lyricsLatencyBySource
    }

    /// 源是否启用。
    /// - Parameter sourceID: 源标识。
    /// - Returns: 未被禁用时为 `true`。
    public func isEnabled(_ sourceID: SourceID) -> Bool {
        !disabled.contains(sourceID)
    }
}

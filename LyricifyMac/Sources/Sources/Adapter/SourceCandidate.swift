import LyricsCore

/// 源候选（S2 §1：TrackRef 匹配信息 + 源内 id + 预览 + 质量提示）。
public struct SourceCandidate: Sendable {
    /// 所属源。
    public var sourceID: SourceID
    /// 源内 id（如 LRCLIB record id）。
    public var id: String
    /// 候选侧曲目信息（匹配用）。
    public var track: TrackRef?
    /// 预览文本（如首行）。
    public var preview: String?
    /// 质量提示。
    public var quality: LyricsQuality

    /// 创建源候选。
    /// - Parameters:
    ///   - sourceID: 所属源。
    ///   - id: 源内 id。
    ///   - track: 候选侧曲目信息，可选。
    ///   - preview: 预览文本，可选。
    ///   - quality: 质量提示。
    public init(
        sourceID: SourceID,
        id: String,
        track: TrackRef? = nil,
        preview: String? = nil,
        quality: LyricsQuality
    ) {
        self.sourceID = sourceID
        self.id = id
        self.track = track
        self.preview = preview
        self.quality = quality
    }
}

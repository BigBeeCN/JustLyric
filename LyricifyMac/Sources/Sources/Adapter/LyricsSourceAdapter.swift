import LyricsCore

/// 歌词源适配器协议（S2 §1）。
///
/// > Important: 合规红线（S0 §3-2）——核心仓库仅实现 LRCLIB/AppleTTML/LocalFiles 三源；
/// > QQ/网易/酷狗/Musixmatch/汽水 等受限源只能以第三方插件实现本协议接入，
/// > 接口调用与其法律责任由插件作者承担，核心仓库不得含其实现。
public protocol LyricsSourceAdapter: Sendable {
    /// 源标识。
    var id: SourceID { get }
    /// 是否支持逐字同步。
    var supportsSyllableSync: Bool { get }
    /// 搜索候选。
    /// - Parameter track: 曲目引用。
    /// - Returns: 候选数组（含匹配信息与质量提示）。
    func search(_ track: TrackRef) async throws -> [SourceCandidate]
    /// 取词。
    /// - Parameter candidate: 源候选。
    /// - Returns: 歌词数据。
    func fetch(_ candidate: SourceCandidate) async throws -> LyricsData
}

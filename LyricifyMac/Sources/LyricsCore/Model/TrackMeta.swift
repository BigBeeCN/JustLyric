/// 文件内元数据（S7 D20：对齐 `TrackRef` 匹配用子集；LocalFiles 匹配线索）。
public struct TrackMeta: Codable, Equatable, Sendable {
    /// 曲名（`ti`）。
    public var title: String?
    /// 艺人列表（`ar`，按 `,`/`、`/`&` 拆）。
    public var artists: [String]
    /// 专辑（`al`）。
    public var album: String?
    /// 时长（毫秒，`length`）。
    public var durationMs: Int?

    /// 创建文件内元数据。
    /// - Parameters:
    ///   - title: 曲名。
    ///   - artists: 艺人列表。
    ///   - album: 专辑。
    ///   - durationMs: 时长（毫秒）。
    public init(
        title: String? = nil,
        artists: [String] = [],
        album: String? = nil,
        durationMs: Int? = nil
    ) {
        self.title = title
        self.artists = artists
        self.album = album
        self.durationMs = durationMs
    }
}

/// 曲目身份（S1 §1，S2/S3 共用）。
public struct TrackRef: Codable, Sendable, Equatable {
    /// 曲名。
    public var title: String
    /// 艺人列表。
    public var artists: [String]
    /// 专辑名。
    public var album: String?
    /// 专辑艺人列表。
    public var albumArtists: [String]?
    /// 时长（毫秒）。
    public var durationMs: Int?
    /// ISRC。
    public var isrc: String?
    /// Spotify URI。
    public var spotifyUri: String?
    /// 来源 app（S3）。
    public var bundleID: String?

    /// 创建曲目引用。
    /// - Parameters:
    ///   - title: 曲名。
    ///   - artists: 艺人列表。
    ///   - album: 专辑名，可选。
    ///   - albumArtists: 专辑艺人列表，可选。
    ///   - durationMs: 时长（毫秒），可选。
    ///   - isrc: ISRC，可选。
    ///   - spotifyUri: Spotify URI，可选。
    ///   - bundleID: 来源 app bundle id，可选。
    public init(
        title: String,
        artists: [String],
        album: String? = nil,
        albumArtists: [String]? = nil,
        durationMs: Int? = nil,
        isrc: String? = nil,
        spotifyUri: String? = nil,
        bundleID: String? = nil
    ) {
        self.title = title
        self.artists = artists
        self.album = album
        self.albumArtists = albumArtists
        self.durationMs = durationMs
        self.isrc = isrc
        self.spotifyUri = spotifyUri
        self.bundleID = bundleID
    }
}

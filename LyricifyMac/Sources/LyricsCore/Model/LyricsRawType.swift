/// 歌词原始格式类型（S1 §1、S7 D1 定案命名）。
///
/// > Note: Apple `amp-api` 的 JSON 信封（"AppleJson"）不是歌词格式，
/// > 由 `Sources/AppleTTML` 适配器解包为 `.ttml`，本枚举不设对应 case（S7 D1）。
public enum LyricsRawType: String, Codable, Sendable {
    /// LRC 行级格式。
    case lrc
    /// 酷狗 KRC 逐字格式。
    case krc
    /// QQ QRC 逐字格式。
    case qrc
    /// 网易 YRC 逐字格式。
    case yrc
    /// Apple Music TTML。
    case ttml
    /// Musixmatch richsync JSON。
    case richSync
    /// Spotify Color Lyrics JSON。
    case spotifyColorLyrics
    /// LyricifySyllable 逐字格式。
    case lyricifySyllable
    /// LyricifyLines 行级格式。
    case lyricifyLines
    /// 未知/不可识别。
    case unknown
}

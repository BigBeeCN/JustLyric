/// 歌词行对齐方式（S1 §1）。默认 `.center`。
public enum LyricsAlignment: String, Codable, Sendable {
    /// 左对齐。
    case left
    /// 居中（默认）。
    case center
    /// 右对齐。
    case right
}

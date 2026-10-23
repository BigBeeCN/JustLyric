import Foundation

/// LRCLIB API 记录（字段：S2 §1.1；宽容解码）。
struct LRCLIBRecord: Codable, Sendable {
    /// 记录 id。
    let id: Int?
    /// 曲名。
    let trackName: String?
    /// 艺人。
    let artistName: String?
    /// 专辑。
    let albumName: String?
    /// 时长（秒）。
    let duration: Double?
    /// 纯音乐标记。
    let instrumental: Bool?
    /// 纯文本歌词。
    let plainLyrics: String?
    /// 行同步歌词（LRC）。
    let syncedLyrics: String?
}

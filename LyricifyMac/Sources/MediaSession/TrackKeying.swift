import Foundation
import LyricsCore

/// track key（S2 §4 缓存 key 同源规则：`isrc ?? spotifyUri ?? (normalized title|artists|duration)`）。
public enum TrackKeying {
    /// 生成 track key。
    /// - Parameter track: 曲目。
    /// - Returns: 稳定 key。
    public static func make(_ track: TrackRef) -> String {
        if let isrc = track.isrc, !isrc.isEmpty {
            return "isrc:\(isrc)"
        }
        if let uri = track.spotifyUri, !uri.isEmpty {
            return "uri:\(uri)"
        }
        let title = NormalizeName(track.title)
        let artists = track.artists.map(NormalizeName).joined(separator: ",")
        return "nat:\(title)|\(artists)|\(track.durationMs ?? -1)"
    }
}

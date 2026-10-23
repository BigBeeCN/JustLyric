import Foundation
import LyricsCore

/// 文件名匹配（S7 D26 #3：三模式兜底；`(Live)` 类质量标记不删除仅弱化匹配）。
enum FilenameMatcher {
    /// 文件名 → 曲目候选（去扩展名）。
    /// - Parameter filename: 文件名（含扩展名）。
    /// - Returns: 候选 `(title, artists)`；顺序：`Artist - Title` / `Title - Artist` / `Title`。
    static func candidates(fromFilename filename: String) -> [(title: String, artists: [String])] {
        let base = (filename as NSString).deletingPathExtension
        var result: [(String, [String])] = []
        if let dashRange = base.range(of: " - ") {
            let left = String(base[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(base[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !left.isEmpty, !right.isEmpty {
                result.append((right, [left])) // Artist - Title
                result.append((left, [right])) // Title - Artist
            }
        }
        let whole = base.trimmingCharacters(in: .whitespaces)
        if !whole.isEmpty {
            result.append((whole, [])) // Title
        }
        return result
    }

    /// 候选与曲目的匹配档（CompareHelper + minMatch，D26 #3）。
    /// - Parameters:
    ///   - candidate: 文件候选。
    ///   - track: 目标曲目。
    /// - Returns: 曲名档与艺人档。
    static func matchLevel(
        of candidate: (title: String, artists: [String]),
        against track: TrackRef
    ) -> (name: NameMatch?, artist: ArtistMatch?) {
        let name = CompareName(candidate.title, track.title)
        let artist = candidate.artists.isEmpty || track.artists.isEmpty
            ? nil
            : CompareArtist(candidate.artists, track.artists)
        return (name, artist)
    }

    /// 是否接受（实现级规则：曲名档 ≥ minMatch）。
    static func isAccepted(
        candidate: (title: String, artists: [String]),
        track: TrackRef,
        minMatch: MatchLevel
    ) -> Bool {
        guard let name = matchLevel(of: candidate, against: track).name else { return false }
        return name >= minMatch
    }
}

import Foundation
import LyricsCore

/// 元数据清洗（S3 §6；S7 D29 #2）。
public enum MetadataSanitizer {
    /// 清洗文本：去 `(feat. …)`、`【…】`，全角空白归一。
    /// - Parameter text: 原始文本。
    /// - Returns: 清洗后文本。
    public static func sanitized(text: String) -> String {
        var result = text
        // 去 `(feat. …)`（大小写不敏感）。
        result = replacingMatches(
            pattern: "\\((?:feat|ft|featuring)\\.[^)]*\\)",
            in: result
        )
        // 去 `【…】`。
        result = replacingMatches(pattern: "【[^】]*】", in: result)
        // 全角空白归一 + 连续空白折叠。
        result = result.replacingOccurrences(of: "\u{3000}", with: " ")
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// 艺术家拆分（S3 §6：`,`/`、`/`&`/` x `）。
    /// - Parameter text: 艺术家文本。
    /// - Returns: 艺人数组（去空）。
    public static func splitArtists(_ text: String) -> [String] {
        var result = text
        for separator in [",", "、", "&"] {
            result = result.replacingOccurrences(of: separator, with: "\u{1}")
        }
        // ` x `（大小写不敏感）。
        result = replacingMatches(pattern: "\\s+[xX]\\s+", in: result, replacement: "\u{1}")
        return result
            .split(separator: "\u{1}")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 产出归一 `TrackRef`（S3 §6：缺失字段降级匹配）。
    /// - Parameters:
    ///   - title: 曲名。
    ///   - artists: 艺人数组/文本。
    ///   - album: 专辑。
    ///   - durationMs: 时长。
    ///   - bundleID: 来源 app。
    /// - Returns: 归一后的曲目引用。
    public static func trackRef(
        title: String?,
        artists: [String],
        album: String?,
        durationMs: Int?,
        bundleID: String?
    ) -> TrackRef {
        let cleanedArtists = artists
            .flatMap { splitArtists($0) }
            .map { sanitized(text: $0) }
            .filter { !$0.isEmpty }
        return TrackRef(
            title: title.map { sanitized(text: $0) } ?? "",
            artists: cleanedArtists,
            album: album.map { sanitized(text: $0) },
            durationMs: durationMs,
            bundleID: bundleID
        )
    }

    /// 正则替换（内部）。
    private static func replacingMatches(
        pattern: String,
        in text: String,
        replacement: String = ""
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text, options: [], range: range, withTemplate: replacement
        )
    }
}

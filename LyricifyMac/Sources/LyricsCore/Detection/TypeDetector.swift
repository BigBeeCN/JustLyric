import Foundation

/// 判定原始格式类型（S1 §3、S1 §5）。
///
/// 判定顺序（S7 D1：AppleJson 信封不入 LyricsCore）：
/// JSON(Musixmatch/Spotify) → XML(TTML) → LyricifyLines 标记 → KRC → YRC →
/// LyricifySyllable → QRC → LyricifyLines 行形态 → LRC → Unknown。
/// > Important: 判型严格使用 S1 §3 正则（S7 D9 双轨制）；解析器宽容度不影响本函数。
/// - Parameter raw: 歌词原始文本。
/// - Returns: 判定的格式类型；无法识别时为 `.unknown`。
public func detectType(_ raw: String) -> LyricsRawType {
    TypeDetector.detect(raw)
}

/// 判型实现（内部）。
enum TypeDetector {
    /// 类型优先级（数值小者优先，与判定顺序一致）。
    private enum Rank: Int, Comparable {
        case json = 1
        case ttml = 2
        case lyricifyLinesMarker = 3
        case krc = 4
        case yrc = 5
        case lyricifySyllable = 6
        case qrc = 7
        case lyricifyLinesForm = 8
        case lrc = 9

        static func < (lhs: Rank, rhs: Rank) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// 判定入口。
    static func detect(_ raw: String) -> LyricsRawType {
        // 输入卫生：剥离 BOM（不属任何格式语法）。
        let text = raw.hasPrefix("\u{FEFF}") ? String(raw.dropFirst()) : raw
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .unknown
        }

        var best: Rank?
        func consider(_ rank: Rank) {
            if best == nil || rank < best! {
                best = rank
            }
        }

        // 1. JSON：依 JSON 结构判定（Musixmatch richsync / Spotify ColorLyrics）。
        if let rank = jsonRank(trimmed) {
            consider(rank)
        }
        // 2. XML(TTML)。
        if trimmed.hasPrefix("<"), trimmed.contains("http://www.w3.org/ns/ttml") {
            consider(.ttml)
        }
        // 3. LyricifyLines 标记。
        if text.contains("[type:LyricifyLines]") {
            consider(.lyricifyLinesMarker)
        }
        // QRC XML 大包（整包判型，ignoreCase）。
        if firstMatch(DetectionPatterns.qrcFullRegex, in: text) {
            consider(.qrc)
        }

        // 4–9. 行扫描（Multiline 语义：逐行以行首锚定）。
        for line in text.components(separatedBy: "\n").map({ $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }) {
            if firstMatch(DetectionPatterns.krcRegex, in: line) {
                return .krc // 最高行级优先级，可提前结束
            }
            if firstMatch(DetectionPatterns.yrcRegex, in: line) {
                consider(.yrc)
                continue
            }
            if firstMatch(DetectionPatterns.lyricifySyllableRegex, in: line) {
                consider(.lyricifySyllable)
                continue
            }
            if firstMatch(DetectionPatterns.qrcRegex, in: line) {
                consider(.qrc)
                continue
            }
            // LyricifyLines 行形态：行头 [ms,ms] 且不含逐字时序（S7 A9 待批推导式）。
            if firstMatch(DetectionPatterns.lyricifyLinesFormRegex, in: line),
               !firstMatch(DetectionPatterns.anySyllableTimingRegex, in: line),
               !firstMatch(DetectionPatterns.lrcRegex, in: line)
            {
                consider(.lyricifyLinesForm)
                continue
            }
            if firstMatch(DetectionPatterns.lrcRegex, in: line) {
                consider(.lrc)
            }
        }

        switch best {
        case .json:
            return jsonType(trimmed) ?? .unknown
        case .ttml:
            return .ttml
        case .lyricifyLinesMarker, .lyricifyLinesForm:
            return .lyricifyLines
        case .krc:
            return .krc
        case .yrc:
            return .yrc
        case .lyricifySyllable:
            return .lyricifySyllable
        case .qrc:
            return .qrc
        case .lrc:
            return .lrc
        case nil:
            return .unknown
        }
    }

    /// JSON 结构判型：返回 `.json` 档位（若命中）。
    private static func jsonRank(_ trimmed: String) -> Rank? {
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return nil }
        return jsonType(trimmed) == nil ? nil : .json
    }

    /// 依 JSON 结构判定具体类型（S7 D13 结构定案；未知键忽略）。
    private static func jsonType(_ trimmed: String) -> LyricsRawType? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) else {
            return nil
        }
        if let dictionary = object as? [String: Any] {
            // Spotify ColorLyrics：根含 lyrics，其内含 lines。
            if let lyrics = dictionary["lyrics"] as? [String: Any], lyrics["lines"] is [Any] {
                return .spotifyColorLyrics
            }
            return nil
        }
        if let array = object as? [Any] {
            // Musixmatch richsync：行数组，元素含 ts/te/l。
            if let first = array.first as? [String: Any],
               first["ts"] != nil, first["te"] != nil, first["l"] is [Any]
            {
                return .richSync
            }
            return nil
        }
        return nil
    }

    /// 正则是否在输入中命中（`^` 行首锚定，逐行由 anchorsMatchLines 保证）。
    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> Bool {
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}

import Foundation

/// QRC XML 大包提取（`<Lyric_1 … LyricContent="…">`，内容为转义文本）。
enum QrcXmlExtractor {
    /// 大包属性提取正则（ignoreCase 由调用方保证，此处直接宽容）。
    private static let contentRegex = try! NSRegularExpression(
        pattern: "<Lyric_1\\b[^>]*\\bLyricContent\\s*=\\s*\"([^\"]*)\"",
        options: [.caseInsensitive]
    )

    /// 提取 `LyricContent` 并反转义（XML 实体 + 字面 `\n`）。
    static func extract(_ raw: String) -> String? {
        let range = NSRange(raw.startIndex ..< raw.endIndex, in: raw)
        guard let match = contentRegex.firstMatch(in: raw, range: range),
              let contentRange = Range(match.range(at: 1), in: raw) else { return nil }
        var content = String(raw[contentRange])
        content = content
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
        content = content.replacingOccurrences(of: "\\n", with: "\n")
        return content
    }
}

/// QRC 逐字解析（S1 §2.3；词块 `text(off,dur)`，off 相对行起始）。
public enum QrcParser {
    /// 解析 QRC 文本（裸格式或 XML 大包）。
    /// - Parameter raw: QRC 原文。
    /// - Returns: 歌词数据（`source == .qrc`）。
    public static func parse(_ raw: String) -> LyricsData {
        let body = QrcXmlExtractor.extract(raw) ?? raw
        var lines: [LyricsLine] = []

        for line in ParsingSupport.cleanedLines(body) {
            let sub = Substring(line)
            guard let header = ParsingSupport.lineHeader(sub) else { continue }
            let lineStart = header.first
            let lineEnd = lineStart + header.second

            var syllables: [Syllable] = []
            for word in ParsingSupport.splitWords(
                header.body,
                timingPattern: "\\((-?\\d+),(\\d+)\\)"
            ) {
                guard !word.text.isEmpty else { continue } // 空词块容忍（S1 §2.3）
                syllables.append(
                    Syllable(
                        text: word.text,
                        startMs: lineStart + word.offset,
                        durationMs: word.duration
                    )
                )
            }

            lines.append(
                LyricsLine(
                    startMs: lineStart,
                    endMs: lineEnd,
                    text: syllables.map(\.text).joined(),
                    syllables: syllables.isEmpty ? nil : syllables
                )
            )
        }

        return LyricsData(lines: lines, syncLevel: .syllableSynced, source: .qrc, raw: raw)
    }
}

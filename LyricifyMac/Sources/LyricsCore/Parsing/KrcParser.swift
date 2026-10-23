import Foundation

/// KRC 逐字解析（S1 §2.2）。
public enum KrcParser {
    /// 元信息头行 `[key:…]`。
    private static let metaRegex = try! NSRegularExpression(
        pattern: "^\\s*\\[[A-Za-z][A-Za-z0-9_]*:.*\\]\\s*$"
    )

    /// 解析 KRC 文本。
    /// - Parameter raw: KRC 原文。
    /// - Returns: 歌词数据（`source == .krc`，词绝对时间 = 行起始 + x）。
    public static func parse(_ raw: String) -> LyricsData {
        var lines: [LyricsLine] = []

        for line in ParsingSupport.cleanedLines(raw) where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            // 剥离元信息头行（[id:…]/[ar:…] 等，S1 §2.2）。
            let nsLine = line as NSString
            if metaRegex.firstMatch(
                in: line,
                range: NSRange(location: 0, length: nsLine.length)
            ) != nil {
                continue
            }

            let sub = Substring(line)
            guard let header = ParsingSupport.lineHeader(sub) else { continue }
            let lineStart = header.first
            let lineEnd = lineStart + header.second

            var syllables: [Syllable] = []
            // KRC：时序块在前、文本在后（S1 §2.2）。
            for word in ParsingSupport.splitWordsForward(
                header.body,
                timingPattern: "<(-?\\d+),(\\d+),\\d+>"
            ) {
                guard !word.text.isEmpty else { continue }
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

        return LyricsData(lines: lines, syncLevel: .syllableSynced, source: .krc, raw: raw)
    }
}

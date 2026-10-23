import Foundation

/// YRC 逐字解析（S1 §2.4；词块三元组 `(x,y,n)`，n 不一致以 text 为准）。
public enum YrcParser {
    /// 解析 YRC 文本。
    /// - Parameter raw: YRC 原文。
    /// - Returns: 歌词数据（`source == .yrc`；credits `c[].tx` 汇入 `writer`）。
    public static func parse(_ raw: String) -> LyricsData {
        var writer: String?
        var lines: [LyricsLine] = []

        for line in ParsingSupport.cleanedLines(raw) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
                // credits 行（S7 D13：{ "t": int, "c": [ { "tx": 文本, … } ] }）。
                if let credits = parseCredits(trimmed) {
                    writer = credits.joined(separator: "、") // A11c 待批
                }
                continue
            }

            let sub = Substring(line)
            guard let header = ParsingSupport.lineHeader(sub) else { continue }
            let lineStart = header.first
            let lineEnd = lineStart + header.second

            var syllables: [Syllable] = []
            // YRC：时序三元组在前、文本在后（S1 §2.4）；n 不一致以 text 为准。
            for word in ParsingSupport.splitWordsForward(
                header.body,
                timingPattern: "\\((-?\\d+),(\\d+),(\\d+)\\)"
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

        return LyricsData(
            lines: lines,
            syncLevel: .syllableSynced,
            writer: writer,
            source: .yrc,
            raw: raw
        )
    }

    /// 提取 credits 文本（宽容解码，未知键忽略）。
    private static func parseCredits(_ text: String) -> [String]? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              let credits = dictionary["c"] as? [Any] else { return nil }
        let names = credits.compactMap { ($0 as? [String: Any])?["tx"] as? String }
        return names.isEmpty ? nil : names
    }
}

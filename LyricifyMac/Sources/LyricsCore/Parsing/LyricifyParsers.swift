import Foundation

/// LyricifySyllable 解析（S1 §2.8；行标 3–8、词块同 QRC）。
public enum LyricifySyllableParser {
    /// 行头 `[n](start,dur)`。
    private static let headerRegex = try! NSRegularExpression(
        pattern: "^\\[(\\d)\\]\\((-?\\d+),(-?\\d+)\\)"
    )

    /// 解析 LyricifySyllable 文本。
    /// - Parameter raw: 原文。
    /// - Returns: 歌词数据（`source == .lyricifySyllable`；`[6|7|8]` 紧跟主行 → `subLine`）。
    public static func parse(_ raw: String) -> LyricsData {
        var lines: [LyricsLine] = []
        var pendingSubLines: [LyricsLine] = []

        func flushSubLines() {
            guard let main = lines.last, !pendingSubLines.isEmpty else { return }
            // 多副行时链式挂载：首个挂主行，其余挂前一个副行。
            let host = main
            for sub in pendingSubLines {
                if host.subLine == nil {
                    host.subLine = sub
                } else {
                    var tail = host.subLine
                    while tail?.subLine != nil {
                        tail = tail?.subLine
                    }
                    tail?.subLine = sub
                }
            }
            pendingSubLines = []
        }

        for line in ParsingSupport.cleanedLines(raw) {
            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)
            guard let header = headerRegex.firstMatch(in: line, range: fullRange),
                  let digitRange = Range(header.range(at: 1), in: line),
                  let startRange = Range(header.range(at: 2), in: line),
                  let durationRange = Range(header.range(at: 3), in: line),
                  let digit = Int(line[digitRange]),
                  let lineStart = Int(line[startRange]),
                  let lineDuration = Int(line[durationRange]),
                  let headerRange = Range(header.range, in: line) else { continue }
            let body = Substring(line[headerRange.upperBound...])

            var syllables: [Syllable] = []
            for word in ParsingSupport.splitWords(
                body,
                timingPattern: "\\((-?\\d+),(\\d+)\\)"
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

            // 括号开头的行标记背景人声（S1 §2.8）。
            let isBracketed = syllables.first?.text.hasPrefix("(") == true
                || syllables.first?.text.hasPrefix("（") == true

            let parsed = LyricsLine(
                startMs: lineStart,
                endMs: lineStart + lineDuration,
                text: syllables.map(\.text).joined(),
                syllables: syllables.isEmpty ? nil : syllables,
                alignment: alignment(for: digit),
                isBackgroundVocal: isBracketed
            )

            if (6 ... 8).contains(digit) {
                pendingSubLines.append(parsed)
            } else {
                flushSubLines()
                lines.append(parsed)
            }
        }
        flushSubLines()

        return LyricsData(
            lines: lines,
            syncLevel: .syllableSynced,
            source: .lyricifySyllable,
            raw: raw
        )
    }

    /// 行标 → 对齐（3/6 居中、4/7 左、5/8 右，S1 §2.8）。
    private static func alignment(for digit: Int) -> LyricsAlignment {
        switch digit {
        case 4, 7: .left
        case 5, 8: .right
        default: .center
        }
    }
}

/// LyricifyLines 解析（S1 §2.9；首行标记 `[type:LyricifyLines]`，行 `[起始,结束]文本`）。
public enum LyricifyLinesParser {
    /// 解析 LyricifyLines 文本。
    /// - Parameter raw: 原文。
    /// - Returns: 歌词数据（`source == .lyricifyLines`）。
    public static func parse(_ raw: String) -> LyricsData {
        var lines: [LyricsLine] = []
        for line in ParsingSupport.cleanedLines(raw) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "[type:LyricifyLines]" {
                continue
            }
            let sub = Substring(trimmed)
            guard let header = ParsingSupport.lineHeader(sub) else { continue }
            lines.append(
                LyricsLine(
                    startMs: header.first,
                    endMs: header.second,
                    text: String(header.body),
                    syllables: nil
                )
            )
        }
        return LyricsData(lines: lines, syncLevel: .lineSynced, source: .lyricifyLines, raw: raw)
    }
}

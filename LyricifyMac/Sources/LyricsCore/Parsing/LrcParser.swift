import Foundation

/// LRC 解析选项（S7 D6：行后缀拆分默认关）。
public struct LrcParseOptions: Sendable {
    /// 是否启用行后缀 `" / "` 拆分翻译（默认 `false`，S7 D6）。
    public var lineSuffixTranslationEnabled: Bool

    /// 创建 LRC 解析选项。
    /// - Parameter lineSuffixTranslationEnabled: 是否启用行后缀拆分翻译。
    public init(lineSuffixTranslationEnabled: Bool = false) {
        self.lineSuffixTranslationEnabled = lineSuffixTranslationEnabled
    }
}

/// LRC 行级解析（S1 §2.1；解析宽容 S7 D9，判型严格不在此层）。
public enum LrcParser {
    /// 属性行 `^[key:value]`。
    private static let attributeRegex = try! NSRegularExpression(
        pattern: "^\\s*\\[([A-Za-z]+):(.*)\\]\\s*$"
    )
    /// 宽容时间戳：`[m:ss]`/`[mm:ss.SS]`/`[mm:ss:SSS]`/`[mm:ss:xx]` + A9 四位分数截断。
    private static let timestampRegex = try! NSRegularExpression(
        pattern: "^\\[(\\d{1,3}):(\\d{1,2})(?:[.:](\\d{1,4}))?\\]"
    )

    /// 解析 LRC 文本。
    /// - Parameters:
    ///   - raw: LRC 原文。
    ///   - options: 解析选项。
    /// - Returns: 歌词数据（`source == .lrc`）。
    public static func parse(_ raw: String, options: LrcParseOptions = LrcParseOptions()) -> LyricsData {
        var offsetMs = 0
        var writer: String?
        var meta = TrackMeta()
        var lines: [LyricsLine] = []

        for line in ParsingSupport.cleanedLines(raw) {
            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)

            // 属性行（A11a：ar/al/ti 无模型槽位暂弃、length 忽略、by→writer）。
            if let match = attributeRegex.firstMatch(in: line, range: fullRange),
               let keyRange = Range(match.range(at: 1), in: line),
               let valueRange = Range(match.range(at: 2), in: line)
            {
                let key = line[keyRange].lowercased()
                let value = line[valueRange].trimmingCharacters(in: .whitespaces)
                switch key {
                case "offset":
                    offsetMs = Int(value) ?? offsetMs
                case "by":
                    writer = value
                case "ti":
                    meta.title = value
                case "ar":
                    meta.artists = value
                        .split(whereSeparator: { $0 == "," || $0 == "、" || $0 == "&" })
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                case "al":
                    meta.album = value
                case "length":
                    meta.durationMs = parseLength(value)
                default:
                    continue
                }
                continue
            }

            // 时间戳行：行首可堆叠多个 → 复制多行（S6 §2.1-3）。
            var timestamps: [Int] = []
            var cursor = line.startIndex
            while cursor < line.endIndex {
                let tail = line[cursor...]
                let tailRange = NSRange(location: 0, length: (tail as NSString).length)
                guard let match = timestampRegex.firstMatch(in: String(tail), range: tailRange),
                      match.range.location == 0,
                      let minutesRange = Range(match.range(at: 1), in: tail),
                      let secondsRange = Range(match.range(at: 2), in: tail) else { break }
                var fraction: String?
                if match.range(at: 3).location != NSNotFound,
                   let fractionRange = Range(match.range(at: 3), in: tail)
                {
                    fraction = String(tail[fractionRange])
                }
                guard let minutes = Int(tail[minutesRange]),
                      let seconds = Int(tail[secondsRange]),
                      let ms = Timing.milliseconds(
                          minutes: minutes,
                          seconds: seconds,
                          fractionDigits: fraction
                      ) else { break }
                timestamps.append(ms)
                if let fullRange = Range(match.range, in: tail) {
                    cursor = fullRange.upperBound
                } else {
                    break
                }
            }

            guard !timestamps.isEmpty else { continue }
            var text = String(line[cursor...])

            // 行后缀 " / " 拆分翻译（默认关，S7 D6）。
            var translation: String?
            if options.lineSuffixTranslationEnabled, let slashRange = text.range(of: " / ") {
                translation = String(text[slashRange.upperBound...])
                text = String(text[..<slashRange.lowerBound])
            }

            for start in timestamps {
                lines.append(
                    LyricsLine(
                        startMs: start,
                        endMs: nil,
                        text: text,
                        translation: translation,
                        syllables: nil
                    )
                )
            }
        }

        let hasMeta = meta.title != nil || !meta.artists.isEmpty
            || meta.album != nil || meta.durationMs != nil
        return LyricsData(
            lines: lines,
            syncLevel: .lineSynced,
            offsetMs: offsetMs,
            writer: writer,
            trackMeta: hasMeta ? meta : nil,
            source: .lrc,
            raw: raw
        )
    }

    /// `length` 属性解析（`mm:ss` / `h:mm:ss` → 毫秒）。
    private static func parseLength(_ value: String) -> Int? {
        let parts = value.split(separator: ":").map(String.init)
        switch parts.count {
        case 2:
            guard let minutes = Int(parts[0]), let seconds = Int(parts[1]) else { return nil }
            return Timing.milliseconds(minutes: minutes, seconds: seconds, fractionDigits: nil)
        case 3:
            guard let hours = Int(parts[0]), let minutes = Int(parts[1]), let seconds = Int(parts[2]) else {
                return nil
            }
            return Timing.milliseconds(
                minutes: hours * 60 + minutes,
                seconds: seconds,
                fractionDigits: nil
            )
        default:
            return nil
        }
    }
}

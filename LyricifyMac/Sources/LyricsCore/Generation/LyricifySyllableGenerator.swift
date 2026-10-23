/// LyricifySyllable 生成器（S1 §4；主行 `[3/4/5]`、副行 `[6/7/8]`）。
public enum LyricifySyllableGenerator {
    /// 生成 LyricifySyllable 文本（副行 `[6|7|8]` 紧跟主行）。
    /// - Parameter data: 歌词数据。
    /// - Returns: LyricifySyllable 文本。
    public static func generate(_ data: LyricsData) -> String {
        var out = ""
        for line in data.lines {
            out += render(line, isSub: false)
            var sub = line.subLine
            while let current = sub {
                out += render(current, isSub: true)
                sub = current.subLine
            }
        }
        return out
    }

    /// 渲染单行（`[n](start,dur)词(off,dur)…`）；主行 3/4/5、副行 6/7/8。
    private static func render(_ line: LyricsLine, isSub: Bool) -> String {
        let start = line.startMs ?? 0
        let duration = max(0, (line.endMs ?? start) - start)
        let digit = switch (line.alignment, isSub) {
        case (.left, false):
            4
        case (.right, false):
            5
        case (.center, false):
            3
        case (.left, true):
            7
        case (.right, true):
            8
        case (.center, true):
            6
        }
        var out = "[\(digit)](\(start),\(duration))"
        if let syllables = line.syllables, !syllables.isEmpty {
            for syllable in syllables {
                out += "\(syllable.text)(\(syllable.startMs - start),\(syllable.durationMs))"
            }
        } else {
            out += "\(line.text)(0,\(duration))"
        }
        return out + "\n"
    }
}

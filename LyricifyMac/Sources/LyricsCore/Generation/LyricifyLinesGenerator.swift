/// 副行输出模式（S1 §4：内嵌/独立）。
///
/// > Note: 内嵌模式以 `" / "` 分隔符拼入主行文本（实现级选择）；
/// > 独立模式将副行输出为独立 `[起始,结束]文本` 行。
public enum SubLinesOutputMode: Sendable {
    /// 内嵌：拼入主行文本（`主行文本 / 副行文本`）。
    case embedded
    /// 独立：副行单独成行。
    case independent
}

/// LyricifyLines 生成器（S1 §4；首行 `[type:LyricifyLines]`）。
public enum LyricifyLinesGenerator {
    /// 生成 LyricifyLines 文本。
    /// - Parameters:
    ///   - data: 歌词数据。
    ///   - subLinesOutputMode: 副行输出模式（默认 `.independent`）。
    /// - Returns: LyricifyLines 文本。
    public static func generate(
        _ data: LyricsData,
        subLinesOutputMode: SubLinesOutputMode = .independent
    ) -> String {
        var out = "[type:LyricifyLines]\n"
        for line in data.lines {
            let start = line.startMs ?? 0
            let end = line.endMs ?? start
            switch subLinesOutputMode {
            case .embedded:
                var text = line.text
                if let sub = line.subLine {
                    text += " / \(sub.text)"
                }
                out += "[\(start),\(end)]\(text)\n"
            case .independent:
                out += "[\(start),\(end)]\(line.text)\n"
                var sub = line.subLine
                while let current = sub {
                    let subStart = current.startMs ?? start
                    let subEnd = current.endMs ?? subStart
                    out += "[\(subStart),\(subEnd)]\(current.text)\n"
                    sub = current.subLine
                }
            }
        }
        return out
    }
}

/// KRC 生成器（S1 §4；词块 `<x,y,0>` 在文本前，x 相对行起始）。
public enum KrcGenerator {
    /// 生成 KRC 文本。
    /// - Parameter data: 歌词数据。
    /// - Returns: KRC 文本。
    public static func generate(_ data: LyricsData) -> String {
        var out = ""
        for line in data.lines {
            let start = line.startMs ?? 0
            let duration = max(0, (line.endMs ?? start) - start)
            out += "[\(start),\(duration)]"
            if let syllables = line.syllables, !syllables.isEmpty {
                for syllable in syllables {
                    out += "<\(syllable.startMs - start),\(syllable.durationMs),0>\(syllable.text)"
                }
            } else {
                out += "<0,\(duration),0>\(line.text)"
            }
            out += "\n"
        }
        return out
    }
}

/// QRC 生成器（S1 §4；词块 `text(x,y)`，x 相对行起始）。
public enum QrcGenerator {
    /// 生成 QRC 文本。
    /// - Parameter data: 歌词数据。
    /// - Returns: QRC 文本。
    public static func generate(_ data: LyricsData) -> String {
        var out = ""
        for line in data.lines {
            let start = line.startMs ?? 0
            let duration = max(0, (line.endMs ?? start) - start)
            out += "[\(start),\(duration)]"
            if let syllables = line.syllables, !syllables.isEmpty {
                for syllable in syllables {
                    out += "\(syllable.text)(\(syllable.startMs - start),\(syllable.durationMs))"
                }
            } else {
                out += "\(line.text)(0,\(duration))"
            }
            out += "\n"
        }
        return out
    }
}

/// YRC 生成器（S1 §4；词块 `(x,y,n)` 在文本前；credits 由 writer 还原）。
public enum YrcGenerator {
    /// 生成 YRC 文本。
    /// - Parameter data: 歌词数据。
    /// - Returns: YRC 文本。
    public static func generate(_ data: LyricsData) -> String {
        var out = ""
        if let writer = data.writer, !writer.isEmpty {
            // A11c/D20：writer 多值以 "、" 连接，反向拆出 credits。
            let credits = writer
                .split(separator: "、")
                .map { "{\"tx\":\"\($0)\"}" }
                .joined(separator: ",")
            out += "{\"t\":1,\"c\":[\(credits)]}\n"
        }
        for line in data.lines {
            let start = line.startMs ?? 0
            let duration = max(0, (line.endMs ?? start) - start)
            out += "[\(start),\(duration)]"
            if let syllables = line.syllables, !syllables.isEmpty {
                for syllable in syllables {
                    let n = syllable.text.count
                    out += "(\(syllable.startMs - start),\(syllable.durationMs),\(n))\(syllable.text)"
                }
            } else {
                out += "(0,\(duration),\(line.text.count))\(line.text)"
            }
            out += "\n"
        }
        return out
    }
}

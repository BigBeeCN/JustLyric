/// 时间戳格式化（生成器共用；A3/D17：`mm:ss.xxx` 3 位毫秒，实测印证 `PrintTimestamp`）。
enum TimestampFormatter {
    /// 毫秒 → `mm:ss.mmm`。
    static func lrcTimestamp(_ ms: Int) -> String {
        let clamped = max(0, ms)
        let minutes = clamped / 60000
        let seconds = (clamped % 60000) / 1000
        let millis = clamped % 1000
        return String(format: "[%02d:%02d.%03d]", minutes, seconds, millis)
    }
}

/// LRC 生成器（S1 §4）。
public enum LrcGenerator {
    /// 生成 LRC 文本。
    ///
    /// > Note: 翻译以行后缀 `" / "` 输出（回读需 `lineSuffixTranslationEnabled`）。
    /// - Parameter data: 歌词数据。
    /// - Returns: LRC 文本。
    public static func generate(_ data: LyricsData) -> String {
        var out = ""
        if let title = data.trackMeta?.title {
            out += "[ti:\(title)]\n"
        }
        if let artists = data.trackMeta?.artists, !artists.isEmpty {
            out += "[ar:\(artists.joined(separator: ","))]\n"
        }
        if let album = data.trackMeta?.album {
            out += "[al:\(album)]\n"
        }
        if let durationMs = data.trackMeta?.durationMs {
            out += "[length:\(String(format: "%02d:%02d", durationMs / 60000, (durationMs % 60000) / 1000))]\n"
        }
        if let writer = data.writer {
            out += "[by:\(writer)]\n"
        }
        if data.offsetMs != 0 {
            out += "[offset:\(data.offsetMs)]\n"
        }

        for line in data.lines {
            var text = line.text
            if let translation = line.translation {
                text += " / \(translation)"
            }
            out += "\(TimestampFormatter.lrcTimestamp(line.startMs ?? 0))\(text)\n"
        }
        return out
    }
}

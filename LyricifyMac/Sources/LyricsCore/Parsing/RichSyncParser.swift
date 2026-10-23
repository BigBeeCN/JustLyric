import Foundation

/// Musixmatch richsync 解析（S1 §2.6；仅作 JSON 输入格式支持，不接其 API）。
public enum RichSyncParser {
    /// 解析 richsync JSON（或 `subtitle_body` 的 LRC 形态）。
    /// - Parameter raw: JSON 原文。
    /// - Returns: 歌词数据（`source == .richSync`）。
    public static func parse(_ raw: String) -> LyricsData {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else {
            return LyricsData(source: .richSync, raw: raw)
        }

        // `track.subtitles.get.subtitle_body` 的 LRC 形态（走 LRC 解析，S1 §2.6）。
        if let dictionary = object as? [String: Any] {
            var body: String?
            if let value = dictionary["subtitle_body"] as? String {
                body = value
            } else if let track = dictionary["track"] as? [String: Any],
                      let subtitles = track["subtitles"] as? [String: Any],
                      let value = subtitles["subtitle_body"] as? String
            {
                body = value
            }
            if let body {
                var result = LrcParser.parse(body)
                result.source = .richSync
                result.raw = raw
                return result
            }
        }

        guard let rows = object as? [Any] else {
            return LyricsData(source: .richSync, raw: raw)
        }

        var lines: [LyricsLine] = []
        for row in rows {
            guard let dictionary = row as? [String: Any] else { continue }
            let ts = double(dictionary["ts"]) ?? 0
            let te = double(dictionary["te"]) ?? 0
            let text = dictionary["x"] as? String ?? ""
            let wordEntries = (dictionary["l"] as? [Any]) ?? []

            var syllables: [Syllable] = []
            var pending: [(text: String, startMs: Int)] = []
            for entry in wordEntries {
                guard let word = entry as? [String: Any] else { continue }
                let wordText = word["c"] as? String ?? ""
                let offset = double(word["o"]) ?? 0
                pending.append((wordText, Timing.milliseconds(fromSeconds: ts + offset)))
            }
            for (index, item) in pending.enumerated() {
                // 词起点 = ts+o；词终点 = 下一词起点；末词 = te（S1 §2.6）。
                let endMs = index + 1 < pending.count
                    ? pending[index + 1].startMs
                    : Timing.milliseconds(fromSeconds: te)
                syllables.append(
                    Syllable(
                        text: item.text,
                        startMs: item.startMs,
                        durationMs: max(0, endMs - item.startMs)
                    )
                )
            }

            lines.append(
                LyricsLine(
                    startMs: Timing.milliseconds(fromSeconds: ts),
                    endMs: Timing.milliseconds(fromSeconds: te),
                    text: text,
                    syllables: syllables.isEmpty ? nil : syllables
                )
            )
        }

        return LyricsData(lines: lines, syncLevel: .syllableSynced, source: .richSync, raw: raw)
    }

    /// 宽容取浮点。
    private static func double(_ any: Any?) -> Double? {
        if let value = any as? Double {
            return value
        }
        if let value = any as? Int {
            return Double(value)
        }
        if let value = any as? String {
            return Double(value)
        }
        return nil
    }
}

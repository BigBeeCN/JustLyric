import Foundation

/// Spotify ColorLyrics 解析（S1 §2.7 字段名 D13；语义 S7 D19）。
///
/// > Important: D19 —— `alternatives` 是备选语言文本（非背景人声），**不映射任何行字段**，
/// > 原样存 `additionalInfo`；禁止挂 `subLine`/`isBackgroundVocal`。
public enum SpotifyLyricsParser {
    /// 解析 ColorLyrics JSON。
    /// - Parameter raw: JSON 原文。
    /// - Returns: 歌词数据（`source == .spotifyColorLyrics`）。
    public static func parse(_ raw: String) -> LyricsData {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lyrics = object["lyrics"] as? [String: Any]
        else {
            return LyricsData(source: .spotifyColorLyrics, raw: raw)
        }

        let syncType = SpotifySyncType(apiValue: lyrics["syncType"] as? String ?? "")
        var lines: [LyricsLine] = []

        for entry in (lyrics["lines"] as? [Any]) ?? [] {
            guard let line = entry as? [String: Any] else { continue }
            let words = line["words"] as? String ?? ""
            let startMs = int(line["startTimeMs"])
            let endMs = int(line["endTimeMs"])
            // D19：endTime==0 视无时序行。
            let timed = endMs != nil && endMs != 0
            let syllableEntries = (line["syllables"] as? [Any]) ?? []

            var syllables: [Syllable] = []
            if !syllableEntries.isEmpty {
                // 词文本 = 依次按 numChars 从行 words 截取（D13 实测语义）。
                var cursor = words.startIndex
                for item in syllableEntries {
                    guard let syllable = item as? [String: Any] else { continue }
                    let numChars = int(syllable["numChars"]) ?? 0
                    let endIndex = words.index(
                        cursor,
                        offsetBy: numChars,
                        limitedBy: words.endIndex
                    ) ?? words.endIndex
                    let text = String(words[cursor ..< endIndex])
                    cursor = endIndex
                    guard let syllableStart = int(syllable["startTimeMs"]) else { continue }
                    let syllableEnd = int(syllable["endTimeMs"]) ?? syllableStart
                    syllables.append(
                        Syllable(
                            text: text,
                            startMs: syllableStart,
                            durationMs: max(0, syllableEnd - syllableStart)
                        )
                    )
                }
            }

            lines.append(
                LyricsLine(
                    startMs: timed ? startMs : nil,
                    endMs: timed ? endMs : nil,
                    text: words,
                    syllables: syllables.isEmpty ? nil : syllables
                )
            )
        }

        // D19：alternatives 原样保留于 additionalInfo。
        var alternatives: [SpotifyAlternative] = []
        for item in (lyrics["alternatives"] as? [Any]) ?? [] {
            guard let dictionary = item as? [String: Any] else { continue }
            alternatives.append(
                SpotifyAlternative(
                    language: dictionary["language"] as? String ?? "",
                    lines: (dictionary["lines"] as? [Any])?.compactMap { $0 as? String } ?? [],
                    isRtlLanguage: dictionary["isRtlLanguage"] as? Bool ?? false
                )
            )
        }

        // D21：syncLevel 由文件级 syncType 决定（未知→.unsynced）。
        let syncLevel: SyncLevel = switch syncType {
        case .syllableSynced:
            .syllableSynced
        case .lineSynced:
            .lineSynced
        case .unsynced, .unknown:
            .unsynced
        }

        return LyricsData(
            lines: lines,
            syncLevel: syncLevel,
            source: .spotifyColorLyrics,
            raw: raw,
            additionalInfo: SpotifyAdditionalInfo(
                syncType: syncType,
                alternatives: alternatives
            )
        )
    }

    /// 双形态容忍（A2/D17：字符串毫秒规范、数字容忍）。
    private static func int(_ any: Any?) -> Int? {
        if let value = any as? Int {
            return value
        }
        if let value = any as? String {
            return Int(value)
        }
        return nil
    }
}

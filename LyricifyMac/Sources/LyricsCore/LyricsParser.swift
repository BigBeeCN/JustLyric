/// 歌词解析分发入口（S1 §5；S7 D9 判型严格、解析宽容）。
///
/// - Parameters:
///   - raw: 歌词原始文本。
///   - type: 指定格式；`nil` 时经 `detectType` 判型。
/// - Returns: 歌词数据；`.unknown` 走纯文本兜底（S7 D20/D21：`syncLevel == .unsynced`）。
public func parse(_ raw: String, type: LyricsRawType? = nil) -> LyricsData {
    let resolved = type ?? detectType(raw)
    switch resolved {
    case .lrc:
        return LrcParser.parse(raw)
    case .krc:
        return KrcParser.parse(raw)
    case .qrc:
        return QrcParser.parse(raw)
    case .yrc:
        return YrcParser.parse(raw)
    case .ttml:
        return TTMLParser.parse(raw)
    case .richSync:
        return RichSyncParser.parse(raw)
    case .spotifyColorLyrics:
        return SpotifyLyricsParser.parse(raw)
    case .lyricifySyllable:
        return LyricifySyllableParser.parse(raw)
    case .lyricifyLines:
        return LyricifyLinesParser.parse(raw)
    case .unknown:
        return plainTextFallback(raw)
    }
}

/// 纯文本兜底（D20/D21）：每非空行一条、无时序、`.unsynced`。
private func plainTextFallback(_ raw: String) -> LyricsData {
    let lines = ParsingSupport.cleanedLines(raw)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .map { LyricsLine(text: $0) }
    return LyricsData(lines: lines, syncLevel: .unsynced, source: .unknown, raw: raw)
}

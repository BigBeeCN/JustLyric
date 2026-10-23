/// 纯函数工具（S1 §5）。
public enum LyricsUtilities {
    /// 纯音乐文案精确集合（S1 §5）。
    private static let instrumentalTexts: Set<String> = [
        "纯音乐，请欣赏",
        "此歌曲为没有填词的纯音乐，请您欣赏",
        "此歌曲为DJ舞曲，请您欣赏",
        "此歌曲为没有填词的DJ舞曲，请您欣赏",
    ]

    /// 是否含 CJK 字符（S2 §3 #1 码位：平假名/片假名/片假名扩展/扩A/基本）。
    /// - Parameter text: 文本。
    /// - Returns: 任一字符落在 CJK 区时为 `true`。
    public static func detectCJK(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3040 ... 0x309F, // 平假名
                 0x30A0 ... 0x30FF, // 片假名
                 0x31F0 ... 0x31FF, // 片假名扩展
                 0x3400 ... 0x4DBF, // CJK 扩A
                 0x4E00 ... 0x9FFF: // CJK 基本
                return true
            default:
                continue
            }
        }
        return false
    }

    /// 行/词统一平移（S1 §5；A5/D17：正值=延后）。
    /// - Parameters:
    ///   - data: 歌词数据。
    ///   - ms: 偏移毫秒。
    /// - Returns: 平移后的新数据（深拷贝）。
    public static func applyOffset(_ data: LyricsData, ms: Int) -> LyricsData {
        var result = data
        result.lines = data.lines.map { shifted($0, ms: ms) }
        return result
    }

    /// 逐字 → 行同步降级（S1 §5：丢 syllables，保 translation/subLine）。
    /// - Parameter data: 歌词数据。
    /// - Returns: 降级后的新数据。
    public static func downgradeToLineSynced(_ data: LyricsData) -> LyricsData {
        var result = data
        result.syncLevel = .lineSynced
        result.lines = data.lines.map(downgradeLine)
        return result
    }

    /// 是否纯音乐（S1 §5：单行且文本命中精确集合）。
    /// - Parameter data: 歌词数据。
    /// - Returns: 命中时为 `true`。
    public static func isInstrumental(_ data: LyricsData) -> Bool {
        guard data.lines.count == 1 else { return false }
        return instrumentalTexts.contains(data.lines[0].text)
    }

    /// 深拷贝并平移行。
    private static func shifted(_ line: LyricsLine, ms: Int) -> LyricsLine {
        let copy = LyricsLine(
            startMs: line.startMs.map { $0 + ms },
            endMs: line.endMs.map { $0 + ms },
            text: line.text,
            translation: line.translation,
            pronunciation: line.pronunciation,
            syllables: line.syllables.map { list in list.map { shiftSyllable($0, ms: ms) } },
            alignment: line.alignment,
            isBackgroundVocal: line.isBackgroundVocal
        )
        copy.subLine = line.subLine.map { shifted($0, ms: ms) }
        return copy
    }

    /// 深拷贝并平移词块。
    private static func shiftSyllable(_ syllable: Syllable, ms: Int) -> Syllable {
        Syllable(
            text: syllable.text,
            startMs: syllable.startMs + ms,
            durationMs: syllable.durationMs,
            subSyllables: syllable.subSyllables.map { $0.map { shiftSyllable($0, ms: ms) } }
        )
    }

    /// 深拷贝并降级行。
    private static func downgradeLine(_ line: LyricsLine) -> LyricsLine {
        let copy = LyricsLine(
            startMs: line.startMs,
            endMs: line.endMs,
            text: line.text,
            translation: line.translation,
            pronunciation: line.pronunciation,
            syllables: nil,
            alignment: line.alignment,
            isBackgroundVocal: line.isBackgroundVocal
        )
        copy.subLine = line.subLine.map(downgradeLine)
        return copy
    }
}

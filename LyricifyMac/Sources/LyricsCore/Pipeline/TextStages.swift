/// 文本级阶段（S2 §3 #2/#5/#6/#9）。
public enum TextStages {
    /// 步骤 2：识别/剥离标题尾行（S7 D17/A1：title 块≤前 3 行、ending 块≤后 3 行，设置可覆盖 auto）。
    ///
    /// - Parameters:
    ///   - data: 歌词数据。
    ///   - titleLinesOverride: `title_lines` 设置覆盖（`nil`=auto）。
    ///   - endingLinesOverride: `ending_lines` 设置覆盖（`nil`=auto）。
    /// - Returns: 剥离后的数据（`titleLines`/`endingLines`/`writer` 已填）。
    public static func cleanInfoLines(
        _ data: LyricsData,
        titleLinesOverride: Int? = nil,
        endingLinesOverride: Int? = nil
    ) -> LyricsData {
        var result = data
        let lines = data.lines
        guard !lines.isEmpty else { return data }

        let names = ([data.trackMeta?.title].compactMap { $0 } + (data.trackMeta?.artists ?? []))
            .map(NormalizeName)
            .filter { !$0.isEmpty }

        // auto：前部/尾部各最多 3 行、连续命中块（D17/A1）。
        var titleCount = 0
        var endingCount = 0
        if titleLinesOverride == nil {
            let limit = min(3, lines.count)
            for index in 0 ..< limit {
                if isNameLine(lines[index].text, names: names) {
                    titleCount = index + 1
                } else {
                    break
                }
            }
        }
        if endingLinesOverride == nil {
            let limit = min(3, lines.count)
            for offset in 0 ..< limit {
                let index = lines.count - 1 - offset
                if index >= 0, isNameLine(lines[index].text, names: names) {
                    endingCount = offset + 1
                } else {
                    break
                }
            }
        }
        let title = titleLinesOverride ?? titleCount
        let ending = endingLinesOverride ?? endingCount

        // writer 提取（作词/作曲/Written by/Lyrics by；提取并剥离）。
        var writers: [String] = []
        for line in lines where isWriterLine(line.text) {
            writers.append(extractWriter(line.text))
        }
        if !writers.isEmpty {
            result.writer = writers.joined(separator: "、")
        }

        // 剥离 title/ending 块与 writer 行。
        let kept = lines.enumerated().compactMap { index, line -> LyricsLine? in
            if index < title {
                return nil
            }
            if ending > 0, index >= lines.count - ending {
                return nil
            }
            if isWriterLine(line.text) {
                return nil
            }
            return line
        }

        result.lines = kept
        result.titleLines = title
        result.endingLines = ending
        return result
    }

    /// 步骤 5：显式标记归一（A12 待批标记集：`🅴`(U+1F134)/`Ⓔ`(U+24BA)；保留/移除可配置）。
    /// - Parameters:
    ///   - data: 歌词数据。
    ///   - policy: `.keep` 归一保留（统一为 🅴）；`.remove` 移除。
    /// - Returns: 归一后的数据。
    public static func explicitNormalize(_ data: LyricsData, policy: ExplicitPolicy) -> LyricsData {
        var result = data
        result.lines = data.lines.map { line in
            let copy = LyricsLine(
                startMs: line.startMs,
                endMs: line.endMs,
                text: normalizeExplicit(line.text, policy: policy),
                translation: line.translation.map { normalizeExplicit($0, policy: policy) },
                pronunciation: line.pronunciation,
                syllables: line.syllables,
                alignment: line.alignment,
                isBackgroundVocal: line.isBackgroundVocal
            )
            copy.subLine = line.subLine.map { sub in
                LyricsLine(
                    startMs: sub.startMs,
                    endMs: sub.endMs,
                    text: normalizeExplicit(sub.text, policy: policy),
                    translation: sub.translation.map { normalizeExplicit($0, policy: policy) },
                    pronunciation: sub.pronunciation,
                    syllables: sub.syllables,
                    alignment: sub.alignment,
                    isBackgroundVocal: sub.isBackgroundVocal
                )
            }
            return copy
        }
        return result
    }

    /// 步骤 6：简繁转换（原文与翻译分别处理）+ CJK 长句切分（maxChars=24）。
    /// - Parameters:
    ///   - data: 歌词数据。
    ///   - preferSimplified: 简体优先。
    ///   - region: 繁体地区（`tw` 默认/`hk`）。
    ///   - segmentationEnabled: 是否启用长句切分。
    /// - Returns: 归一后的数据。
    public static func chineseNormalize(
        _ data: LyricsData,
        preferSimplified: Bool,
        region: ChineseRegion = .tw,
        segmentationEnabled: Bool = true
    ) -> LyricsData {
        let converter = OpenCCChineseConverter.shared
        func convert(_ text: String) -> String {
            preferSimplified
                ? converter.toSimplified(text)
                : converter.toTraditional(text, region: region)
        }

        var result = data
        result.lines = data.lines.map { line in
            let copy = LyricsLine(
                startMs: line.startMs,
                endMs: line.endMs,
                text: convert(line.text),
                translation: line.translation.map(convert),
                pronunciation: line.pronunciation,
                syllables: line.syllables,
                alignment: line.alignment,
                isBackgroundVocal: line.isBackgroundVocal
            )
            copy.subLine = line.subLine
            return copy
        }
        if segmentationEnabled {
            result = SentenceSplitter.splitLongChineseSentences(result, maxChars: 24)
        }
        return result
    }

    /// 步骤 9：副行识别（括号行 `(`/`（` 开头 → `isBackgroundVocal`）。
    /// - Parameter data: 歌词数据。
    /// - Returns: 标记后的数据。
    public static func backgroundVocalDetect(_ data: LyricsData) -> LyricsData {
        var result = data
        result.lines = data.lines.map { line in
            let copy = LyricsLine(
                startMs: line.startMs,
                endMs: line.endMs,
                text: line.text,
                translation: line.translation,
                pronunciation: line.pronunciation,
                syllables: line.syllables,
                alignment: line.alignment,
                isBackgroundVocal: line.isBackgroundVocal
                    || line.text.hasPrefix("(")
                    || line.text.hasPrefix("（")
            )
            copy.subLine = line.subLine
            return copy
        }
        return result
    }

    /// 显式标记策略。
    public enum ExplicitPolicy: Sendable {
        /// 归一保留（统一为 `🅴`）。
        case keep
        /// 移除。
        case remove
    }

    // MARK: - 私有

    /// 显式标记集合（A12 待批）。
    private static let explicitMarkers = ["\u{1F134}", "\u{24BA}"]

    private static func normalizeExplicit(_ text: String, policy: ExplicitPolicy) -> String {
        var result = text
        for marker in explicitMarkers {
            switch policy {
            case .remove:
                result = result.replacingOccurrences(of: marker, with: "")
            case .keep:
                result = result.replacingOccurrences(of: marker, with: "\u{1F134}")
            }
        }
        return result
    }

    private static func isNameLine(_ text: String, names: [String]) -> Bool {
        let normalized = NormalizeName(text)
        return names.contains { normalized.contains($0) }
    }

    private static let writerMarkers = ["作词", "作曲", "Written by", "Lyrics by"]

    private static func isWriterLine(_ text: String) -> Bool {
        writerMarkers.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func extractWriter(_ text: String) -> String {
        for separator in ["：", ":"] {
            if let range = text.range(of: separator) {
                return String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return text.trimmingCharacters(in: .whitespaces)
    }
}

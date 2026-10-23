/// CJK 长句切分（S1 §5 + S2 §3 #6；`maxChars=24`，按 `，。！？、；` 优先切）。
public enum SentenceSplitter {
    /// 优先切分标点集。
    private static let punctuation: Set<Character> = ["，", "。", "！", "？", "、", "；"]

    /// 长句按标点/长度切行，时间按比例分配、总时长守恒（S6 §2.4-5）。
    /// - Parameters:
    ///   - data: 歌词数据。
    ///   - maxChars: 单行最大字符数（默认 24）。
    /// - Returns: 切分后的新数据。
    public static func splitLongChineseSentences(
        _ data: LyricsData,
        maxChars: Int = 24
    ) -> LyricsData {
        var result = data
        // D45 修复：仅 CJK 行参与切分（S2 §3 #6 字面"CJK 长句切分"）；
        // 英文行曾被误切为同 start 双段 → UI 只见尾段（复现定罪）。
        result.lines = data.lines.flatMap { line -> [LyricsLine] in
            guard LyricsUtilities.detectCJK(line.text) else { return [line] }
            // endMs 缺失（LRC）→ 用下一行 start 推定，保证时间分配守恒、不产生同 start 双段。
            if line.endMs == nil, let start = line.startMs {
                let next = data.lines
                    .compactMap(\.startMs)
                    .first { $0 > start }
                let copy = LyricsLine(
                    startMs: start,
                    endMs: next,
                    text: line.text,
                    translation: line.translation,
                    pronunciation: line.pronunciation,
                    syllables: line.syllables,
                    alignment: line.alignment,
                    isBackgroundVocal: line.isBackgroundVocal
                )
                copy.subLine = line.subLine
                return splitLine(copy, maxChars: maxChars)
            }
            return splitLine(line, maxChars: maxChars)
        }
        return result
    }

    /// 切分单行。
    private static func splitLine(_ line: LyricsLine, maxChars: Int) -> [LyricsLine] {
        let chars = Array(line.text)
        // 时间跨度不可定时不切（D45：同 start 双段是 UI 尾段病根）。
        if line.endMs == nil {
            return [line]
        }
        guard chars.count > maxChars else {
            let copy = LyricsLine(
                startMs: line.startMs,
                endMs: line.endMs,
                text: line.text,
                translation: line.translation,
                pronunciation: line.pronunciation,
                syllables: line.syllables,
                alignment: line.alignment,
                isBackgroundVocal: line.isBackgroundVocal
            )
            copy.subLine = line.subLine
            return [copy]
        }

        // 切点：优先标点（≤maxChars 内最后一个标点），否则直接按长度切。
        var cuts: [Int] = [] // 切点为段末字符下标（含）
        var start = 0
        while start < chars.count {
            let end = min(start + maxChars, chars.count)
            if end == chars.count {
                cuts.append(chars.count - 1)
                break
            }
            var cut = end - 1
            while cut > start, !punctuation.contains(chars[cut]) {
                cut -= 1
            }
            if cut == start, !punctuation.contains(chars[cut]) {
                cut = end - 1 // 无标点兜底：按长度切
            }
            cuts.append(cut)
            start = cut + 1
        }

        // 段字符区间。
        var segments: [(start: Int, end: Int)] = []
        var segmentStart = 0
        for cut in cuts {
            segments.append((segmentStart, cut))
            segmentStart = cut + 1
        }

        // 翻译分配（A4/D17：翻译优先同步切分，无切点挂首行）。
        let translations = allocateTranslation(line.translation, segments: segments)

        var result: [LyricsLine] = []
        for (index, segment) in segments.enumerated() {
            let text = String(chars[segment.start ... segment.end])
            let syllables: [Syllable]?
            var startMs = line.startMs
            var endMs = line.endMs

            if let lineSyllables = line.syllables, !lineSyllables.isEmpty {
                // 时间按词块整体归属切分（总时长守恒）。
                var picked: [Syllable] = []
                var position = 0
                for syllable in lineSyllables {
                    let length = syllable.text.count
                    if position >= segment.start, position <= segment.end {
                        picked.append(syllable)
                    }
                    position += length
                }
                syllables = picked.isEmpty ? nil : picked
                if let first = picked.first, let last = picked.last {
                    startMs = first.startMs
                    endMs = last.startMs + last.durationMs
                }
            } else {
                // 行级：按字符比例分配时间（总时长守恒）。
                syllables = nil
                if let lineStart = line.startMs, let lineEnd = line.endMs {
                    let total = chars.count
                    let duration = lineEnd - lineStart
                    startMs = lineStart + duration * segment.start / total
                    endMs = lineStart + duration * (segment.end + 1) / total
                }
            }

            let copy = LyricsLine(
                startMs: startMs,
                endMs: endMs,
                text: text,
                translation: translations[index],
                pronunciation: line.pronunciation,
                syllables: syllables,
                alignment: line.alignment,
                isBackgroundVocal: line.isBackgroundVocal
            )
            if index == 0 {
                copy.subLine = line.subLine
            }
            result.append(copy)
        }
        return result
    }

    /// 翻译分配：按切点数同步切分；无切点整段挂首行（A4/D17）。
    private static func allocateTranslation(
        _ translation: String?,
        segments: [(start: Int, end: Int)]
    ) -> [String?] {
        var result = [String?](repeating: nil, count: segments.count)
        guard let translation, !translation.isEmpty else { return result }
        let parts = translation.split(
            omittingEmptySubsequences: false,
            whereSeparator: { punctuation.contains($0) }
        ).map(String.init).filter { !$0.isEmpty }

        if parts.count <= 1 {
            result[0] = translation // 无切点挂首行
            return result
        }
        for (index, part) in parts.enumerated() {
            let target = min(index, segments.count - 1)
            result[target] = (result[target] ?? "") + part
        }
        return result
    }
}

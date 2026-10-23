/// 词块级阶段（S2 §3 #1/#3）。
public enum SyllableStages {
    /// 步骤 1：西文相邻音节合并为词；CJK 不合并（S2 §3 #1 合并条件四谓词全真）。
    /// - Parameter data: 歌词数据。
    /// - Returns: 合并后的新数据。
    public static func mergeSyllables(_ data: LyricsData) -> LyricsData {
        var result = data
        result.lines = data.lines.map { line in
            let copy = copyLine(line)
            copy.syllables = line.syllables.map { merge($0) }
            copy.subLine = line.subLine.map { sub in
                let subCopy = copyLine(sub)
                subCopy.syllables = sub.syllables.map { merge($0) }
                return subCopy
            }
            return copy
        }
        return result
    }

    /// 步骤 3：无逐字数据→行同步；异常词块（负时长/重叠>50%）修复或降级。
    /// - Parameter data: 歌词数据。
    /// - Returns: 修复或降级后的数据。
    public static func downgradeIfNoSyllable(_ data: LyricsData) -> LyricsData {
        let hasSyllables = data.lines.contains { ($0.syllables?.isEmpty == false) }
        guard hasSyllables else {
            return LyricsUtilities.downgradeToLineSynced(data)
        }

        var needsDowngrade = false
        for line in data.lines {
            guard var syllables = line.syllables, syllables.count > 1 else { continue }
            for index in syllables.indices {
                // 负时长修复为 0。
                if syllables[index].durationMs < 0 {
                    syllables[index].durationMs = 0
                }
                // 重叠 > 50%（占较短块）→ 降级。
                if index > 0 {
                    let previous = syllables[index - 1]
                    let previousEnd = previous.startMs + previous.durationMs
                    let overlap = previousEnd - syllables[index].startMs
                    let shorter = min(previous.durationMs, syllables[index].durationMs)
                    if shorter > 0, overlap * 2 > shorter {
                        needsDowngrade = true
                    }
                }
            }
            line.syllables = syllables
        }
        return needsDowngrade ? LyricsUtilities.downgradeToLineSynced(data) : data
    }

    /// 合并音节数组（条件四谓词全真才合并）。
    private static func merge(_ syllables: [Syllable]) -> [Syllable] {
        guard syllables.count > 1 else { return syllables }
        var merged: [Syllable] = []
        var current = syllables[0]
        for next in syllables.dropFirst() {
            let previousEndsNonSpace = current.text.last.map { !$0.isWhitespace } ?? false
            let nextStartsNonSpace = next.text.first.map { !$0.isWhitespace } ?? false
            let bothNonCJK = !LyricsUtilities.detectCJK(current.text)
                && !LyricsUtilities.detectCJK(next.text)
            let previousHasAlnum = current.text.contains { $0.isLetter || $0.isNumber }
            let nextHasAlnum = next.text.contains { $0.isLetter || $0.isNumber }

            if previousEndsNonSpace, nextStartsNonSpace, bothNonCJK,
               previousHasAlnum, nextHasAlnum
            {
                let end = max(current.startMs + current.durationMs, next.startMs + next.durationMs)
                let combined = Syllable(
                    text: current.text + next.text,
                    startMs: min(current.startMs, next.startMs),
                    durationMs: end - min(current.startMs, next.startMs),
                    subSyllables: (current.subSyllables ?? [current]) + (next.subSyllables ?? [next])
                )
                current = combined
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)
        return merged
    }

    /// 行深拷贝（subLine 保留引用处理由调用方负责）。
    private static func copyLine(_ line: LyricsLine) -> LyricsLine {
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
        return copy
    }
}

import Foundation

/// TTML 解析（S1 §2.5；命名空间 `http://www.w3.org/ns/ttml`）。
public enum TTMLParser {
    /// 解析 TTML 文本。
    /// - Parameter raw: TTML 原文。
    /// - Returns: 歌词数据（`source == .ttml`）。
    public static func parse(_ raw: String) -> LyricsData {
        let delegate = TTMLDelegate()
        let parser = XMLParser(data: Data(raw.utf8))
        parser.delegate = delegate
        parser.parse()
        return delegate.buildData(raw: raw)
    }

    /// 时间表达式解析：`mm:ss.SSS`、`hh:mm:ss.SSS`、秒浮点（可带 `s` 后缀）。
    static func timeMs(_ expression: String) -> Int? {
        let text = expression.trimmingCharacters(in: .whitespaces)
        if text.contains(":") {
            let parts = text.split(separator: ":")
            guard parts.count == 2 || parts.count == 3 else { return nil }
            var hours = 0
            let minutesPart: Substring
            let secondsPart: Substring
            if parts.count == 3 {
                guard let h = Int(parts[0]) else { return nil }
                hours = h
                minutesPart = parts[1]
                secondsPart = parts[2]
            } else {
                minutesPart = parts[0]
                secondsPart = parts[1]
            }
            guard let minutes = Int(minutesPart) else { return nil }
            let secondParts = secondsPart.split(separator: ".", maxSplits: 1)
            guard let seconds = Int(secondParts[0]) else { return nil }
            let fraction = secondParts.count > 1 ? String(secondParts[1]) : nil
            guard let ms = Timing.milliseconds(
                minutes: hours * 60 + minutes,
                seconds: seconds,
                fractionDigits: fraction
            ) else { return nil }
            return ms
        }
        let numeric = text.hasSuffix("s") ? String(text.dropLast()) : text
        guard let seconds = Double(numeric) else { return nil }
        return Timing.milliseconds(fromSeconds: seconds)
    }
}

/// TTML 解析代理（内部）。
private final class TTMLDelegate: NSObject, XMLParserDelegate {
    /// 词块收集。
    private struct Word {
        var text: String
        var startMs: Int?
        var endMs: Int?
    }

    private var lines: [(startMs: Int?, endMs: Int?, words: [Word], translation: String?)] = []
    private var agents: [(role: String?, name: String)] = []
    private var currentWords: [Word] = []
    private var currentTranslation: String?
    private var currentLineStart: Int?
    private var currentLineEnd: Int?
    private var elementStack: [String] = []
    private var textBuffer = ""
    private var spanRole: String?
    private var spanBegin: Int?
    private var spanEnd: Int?
    private var agentRole: String?
    private var agentName = ""
    private var runningEndMs: Int?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String]
    ) {
        elementStack.append(elementName)
        textBuffer = ""
        switch elementName {
        case "p":
            currentLineStart = attributeDict["begin"].flatMap(TTMLParser.timeMs)
            currentLineEnd = attributeDict["end"].flatMap(TTMLParser.timeMs)
            currentWords = []
            currentTranslation = nil
        case "span":
            spanRole = attributeDict["role"]
            spanBegin = attributeDict["begin"].flatMap(TTMLParser.timeMs)
            spanEnd = attributeDict["end"].flatMap(TTMLParser.timeMs)
            if spanEnd == nil, let dur = attributeDict["dur"].flatMap(TTMLParser.timeMs) {
                spanEnd = (spanBegin ?? runningEndMs ?? 0) + dur
            }
        case "agent":
            agentRole = attributeDict["role"]
            agentName = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        switch elementName {
        case "span":
            let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            let begin = spanBegin ?? runningEndMs
            if spanRole?.contains("translation") == true {
                currentTranslation = text
            } else if !text.isEmpty {
                currentWords.append(Word(text: text, startMs: begin, endMs: spanEnd))
                runningEndMs = spanEnd
            }
            spanRole = nil
            spanBegin = nil
            spanEnd = nil
        case "p":
            // 行级兜底：<p> 直接文本（无 span）。
            if currentWords.isEmpty {
                let direct = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !direct.isEmpty {
                    currentWords.append(
                        Word(
                            text: direct,
                            startMs: currentLineStart ?? runningEndMs,
                            endMs: currentLineEnd
                        )
                    )
                }
            }
            lines.append(
                (
                    startMs: currentLineStart,
                    endMs: currentLineEnd,
                    words: currentWords,
                    translation: currentTranslation
                )
            )
        case "name":
            agentName = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "agent":
            if !agentName.isEmpty {
                agents.append((role: agentRole, name: agentName))
            }
            agentRole = nil
        default:
            break
        }
        textBuffer = ""
        if !elementStack.isEmpty {
            elementStack.removeLast()
        }
    }

    /// 构建歌词数据。
    func buildData(raw: String) -> LyricsData {
        var result: [LyricsLine] = []
        var hasSyllables = false
        for entry in lines {
            var syllables: [Syllable] = []
            for word in entry.words {
                guard let start = word.startMs else { continue }
                hasSyllables = true
                let end = word.endMs ?? start
                syllables.append(
                    Syllable(text: word.text, startMs: start, durationMs: max(0, end - start))
                )
            }
            let line = LyricsLine(
                startMs: entry.startMs ?? entry.words.first?.startMs,
                endMs: entry.endMs,
                text: entry.words.map(\.text).joined(),
                translation: entry.translation,
                syllables: syllables.isEmpty ? nil : syllables
            )
            result.append(line)
        }

        // D20：role=l/c → writer；role=artist/vocalist → trackMeta.artists；其余忽略。
        let writerNames = agents.filter { $0.role == "l" || $0.role == "c" }.map(\.name)
        let writer = writerNames.isEmpty ? nil : writerNames.joined(separator: "、")
        let artistNames = agents.filter { $0.role == "artist" || $0.role == "vocalist" }.map(\.name)
        var trackMeta: TrackMeta?
        if !artistNames.isEmpty {
            trackMeta = TrackMeta(artists: artistNames)
        }

        return LyricsData(
            lines: result,
            syncLevel: hasSyllables ? .syllableSynced : .lineSynced,
            writer: writer,
            trackMeta: trackMeta,
            source: .ttml,
            raw: raw
        )
    }
}

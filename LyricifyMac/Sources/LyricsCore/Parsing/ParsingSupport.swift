import Foundation

/// 解析共用支撑（内部）。
enum ParsingSupport {
    /// 输入卫生：剥离 BOM、按 `\n` 拆行、去尾部 `\r`。
    static func cleanedLines(_ raw: String) -> [String] {
        let text = raw.hasPrefix("\u{FEFF}") ? String(raw.dropFirst()) : raw
        return text.components(separatedBy: "\n").map {
            $0.hasSuffix("\r") ? String($0.dropLast()) : $0
        }
    }

    /// 行头 `[a,b]`（整数对）匹配结果。
    struct LineHeader {
        /// 首值。
        let first: Int
        /// 次值。
        let second: Int
        /// 行头之后的正文范围。
        let body: Substring
    }

    /// 匹配 `[a,b]` 行头。
    static func lineHeader(_ line: Substring) -> LineHeader? {
        guard line.hasPrefix("["), let close = line.firstIndex(of: "]") else { return nil }
        let inner = line[line.index(after: line.startIndex) ..< close]
        let parts = inner.split(separator: ",")
        guard parts.count == 2,
              let first = Int(parts[0]), let second = Int(parts[1]) else { return nil }
        return LineHeader(first: first, second: second, body: line[line.index(after: close)...])
    }

    /// 按时序块正则切词：`text(timing)` 形态（QRC/Lyricify/YRC 共用）。
    /// - Parameters:
    ///   - body: 行正文。
    ///   - pattern: 时序块正则（捕获组 1/2 为偏移/时长，YRC 组 3 为字符数）。
    /// - Returns: (词文本, 偏移, 时长, 字符数?) 数组。
    static func splitWords(
        _ body: Substring,
        timingPattern: String
    ) -> [(text: String, offset: Int, duration: Int, charCount: Int?)] {
        let bodyString = String(body)
        let regex = try! NSRegularExpression(pattern: timingPattern)
        let range = NSRange(bodyString.startIndex ..< bodyString.endIndex, in: bodyString)
        var result: [(String, Int, Int, Int?)] = []
        var cursor = bodyString.startIndex
        for match in regex.matches(in: bodyString, range: range) {
            guard let fullRange = Range(match.range, in: bodyString),
                  let offsetRange = Range(match.range(at: 1), in: bodyString),
                  let durationRange = Range(match.range(at: 2), in: bodyString),
                  let offset = Int(bodyString[offsetRange]),
                  let duration = Int(bodyString[durationRange]) else { continue }
            var charCount: Int?
            if match.numberOfRanges > 3,
               match.range(at: 3).location != NSNotFound,
               let countRange = Range(match.range(at: 3), in: bodyString)
            {
                charCount = Int(bodyString[countRange])
            }
            let text = String(bodyString[cursor ..< fullRange.lowerBound])
            result.append((text, offset, duration, charCount))
            cursor = fullRange.upperBound
        }
        return result
    }

    /// 按时序块正则切词（块在前、文本在后：KRC/YRC 形态）。
    /// - Parameters:
    ///   - body: 行正文。
    ///   - pattern: 时序块正则。
    /// - Returns: (词文本, 偏移, 时长, 字符数?) 数组。
    static func splitWordsForward(
        _ body: Substring,
        timingPattern: String
    ) -> [(text: String, offset: Int, duration: Int, charCount: Int?)] {
        let bodyString = String(body)
        let regex = try! NSRegularExpression(pattern: timingPattern)
        let range = NSRange(bodyString.startIndex ..< bodyString.endIndex, in: bodyString)
        let matches = regex.matches(in: bodyString, range: range)
        var result: [(String, Int, Int, Int?)] = []
        for (index, match) in matches.enumerated() {
            guard let fullRange = Range(match.range, in: bodyString),
                  let offsetRange = Range(match.range(at: 1), in: bodyString),
                  let durationRange = Range(match.range(at: 2), in: bodyString),
                  let offset = Int(bodyString[offsetRange]),
                  let duration = Int(bodyString[durationRange]) else { continue }
            var charCount: Int?
            if match.numberOfRanges > 3,
               match.range(at: 3).location != NSNotFound,
               let countRange = Range(match.range(at: 3), in: bodyString)
            {
                charCount = Int(bodyString[countRange])
            }
            let textEnd = index + 1 < matches.count
                ? Range(matches[index + 1].range, in: bodyString)?.lowerBound ?? bodyString.endIndex
                : bodyString.endIndex
            let text = String(bodyString[fullRange.upperBound ..< textEnd])
            result.append((text, offset, duration, charCount))
        }
        return result
    }
}

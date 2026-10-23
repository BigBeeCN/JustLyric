import Foundation

/// 名称归一化（S2 §2.2 步骤 1）：繁→简（t2s 词组级）、lowercase、trim、
/// `’→'`、`，→,`、`（）→()`、`[]→()`。
///
/// > Important: 繁→简必须词组级（S7 D5），匹配比较（CompareName/CompareArtist）统一走本函数。
/// - Parameter text: 原始文本。
/// - Returns: 归一化后的文本。
public func NormalizeName(_ text: String) -> String {
    var result = OpenCCChineseConverter.shared.toSimplified(text)
    result = result.lowercased()
    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    result = result.replacingOccurrences(of: "’", with: "'")
    result = result.replacingOccurrences(of: "，", with: ",")
    result = result.replacingOccurrences(of: "（", with: "(")
    result = result.replacingOccurrences(of: "）", with: ")")
    result = result.replacingOccurrences(of: "[", with: "(")
    result = result.replacingOccurrences(of: "]", with: ")")
    return result
}

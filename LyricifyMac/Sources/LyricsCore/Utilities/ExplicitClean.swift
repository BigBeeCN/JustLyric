import Foundation

/// 脏话掩码（S7 D22：独立关注点，与 `explicitNormalize` 标记归一分离；实测清单见 research/Explicit.cs）。
///
/// 双方向（D22 提示 #1，勿混）：
/// - ``fix(_:)``（FixExplicit）：**还原**误写掩码 → 原词（`f**k→fuck`）；
/// - ``clean(_:strong:)``（Explicit.Clean）：**掩码**输出（`bitch→*****` / `b***h`）。
public enum ExplicitClean {
    /// 还原表（掩码形态正则 → 原词；实测清单 28 条事实移植）。
    public static let fixReplacements: [(pattern: String, replacement: String)] = [
        ("a\\*s", "ass"),
        ("a\\*\\*", "ass"),
        ("b\\*{3}h", "bitch"),
        ("b\\*{2}ch", "bitch"),
        ("b\\*{5}s", "bitches"),
        ("d\\*{2}n", "damn"),
        ("d\\*{2}mit", "dammit"),
        ("d\\*{2}k", "dick"),
        ("d\\*{2}e", "dope"),
        ("f\\*{2}k", "fuck"),
        ("f\\*ck", "fuck"),
        ("fu\\*k", "fuck"),
        ("h\\*e", "hoe"),
        ("h\\*{2}s", "hoes"),
        ("mother\\*{4}", "motherfuck"),
        ("n\\*{3}a", "nigga"),
        ("n\\*{2}ga", "nigga"),
        ("ni\\*{2}a", "nigga"),
        ("n\\*{3}as", "nigras"),
        ("p\\*{3}y", "pussy"),
        ("p\\*{2}sy", "pussy"),
        ("sh\\*t", "shit"),
        ("s\\*x", "sex"),
        ("s\\*{2}t", "shit"),
        ("w\\*{2}d", "weed"),
        ("w\\*{3}e", "whore"),
        ("c\\*{4}e", "cocaine"),
        ("d\\*{2}g", "drug"),
    ]

    /// 全掩码表（strong：整词星号，长度同词）。
    private static let strongMasks: [String: String] = [
        "bitches": "*****", "bitch": "*****",
        "damn": "****", "dammit": "******",
        "dick": "****", "dope": "****", "fuck": "****",
        "nigga": "*****", "nigras": "******",
        "pussy": "*****", "sex": "***", "shit": "****",
        "weed": "****", "whore": "*****",
        "cocaine": "*******", "drug": "****",
    ]

    /// 部分掩码表（非 strong：保留首尾字母）。
    private static let weakMasks: [String: String] = [
        "bitches": "b****s", "bitch": "b***h",
        "damn": "d**n", "dammit": "d**mit",
        "dick": "d**k", "dope": "d**e", "fuck": "f**k",
        "nigga": "n***a", "nigras": "n***as",
        "pussy": "p***y", "sex": "s*x", "shit": "s**t",
        "weed": "w**d", "whore": "w***e",
        "cocaine": "c*****e", "drug": "d**g",
    ]

    /// 还原误写掩码（FixExplicit）。
    /// - Parameter text: 文本。
    /// - Returns: 还原后文本。
    public static func fix(_ text: String) -> String {
        var result = text
        for item in fixReplacements {
            guard let regex = try? NSRegularExpression(pattern: item.pattern) else { continue }
            let range = NSRange(result.startIndex ..< result.endIndex, in: result)
            result = regex.stringByReplacingMatches(
                in: result, options: [], range: range, withTemplate: item.replacement
            )
        }
        return result
    }

    /// 掩码输出（Explicit.Clean）。
    /// - Parameters:
    ///   - text: 文本。
    ///   - strong: `true`=先还原再整词全星号；`false`=保留首尾字母部分掩码。
    /// - Returns: 掩码后文本。
    public static func clean(_ text: String, strong: Bool = false) -> String {
        var result = strong ? fix(text) : text
        let table = strong ? strongMasks : weakMasks

        // 长词优先（防 bitches 被 bitch 截断）。
        for key in table.keys.sorted(by: { $0.count > $1.count }) {
            guard let mask = table[key] else { continue }
            result = result.replacingOccurrences(of: key, with: mask)
            result = result.replacingOccurrences(
                of: capitalized(key), with: capitalized(mask, masking: true)
            )
        }

        // 独立词上下文掩码：ass/Ass/hoe（前后为 空白/连字符/边界 才替换）。
        result = maskStandalone(result, word: "ass", mask: strong ? "***" : "a*s")
        result = maskStandalone(result, word: "Ass", mask: strong ? "***" : "A*s")
        result = maskStandalone(result, word: "hoe", mask: strong ? "***" : "h*e")
        return result
    }

    // MARK: - 私有

    /// 首字母大写（掩码输出保持原词形）。
    private static func capitalized(_ word: String, masking: Bool = false) -> String {
        guard let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst()
    }

    /// 独立词掩码（实测语义：前后边界为 空白/连字符/起止）。
    private static func maskStandalone(_ text: String, word: String, mask: String) -> String {
        var chars = Array(text)
        let wordChars = Array(word)
        var index = 0
        while index + wordChars.count <= chars.count {
            guard Array(chars[index ..< (index + wordChars.count)]) == wordChars else {
                index += 1
                continue
            }
            let beforeOK = index == 0 || chars[index - 1] == " " || chars[index - 1] == "-"
            let afterIndex = index + wordChars.count
            let afterOK = afterIndex == chars.count
                || chars[afterIndex] == " "
                || chars[afterIndex] == "-"
            guard beforeOK, afterOK else {
                index += 1
                continue
            }
            chars.replaceSubrange(
                index ..< (index + wordChars.count),
                with: Array(mask)
            )
            index += mask.count
        }
        return String(chars)
    }
}

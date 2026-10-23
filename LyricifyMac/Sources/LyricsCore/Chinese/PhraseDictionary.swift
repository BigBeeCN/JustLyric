import Foundation

/// OpenCC 词典（词组级最长匹配；格式 `key\tvalue1 value2 …`，取首个候选）。
struct PhraseDictionary {
    /// 词条映射。
    let map: [String: String]
    /// 最长键长度（字符数）。
    let maxKeyLength: Int

    /// 从词典文件加载。
    init(contentsOf url: URL) {
        var map: [String: String] = [:]
        var maxKeyLength = 0
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                if line.hasPrefix("#") {
                    continue
                }
                let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { continue }
                let key = String(parts[0])
                guard !key.isEmpty else { continue }
                let firstValue = parts[1].split(separator: " ").first.map(String.init) ?? ""
                map[key] = firstValue
                maxKeyLength = max(maxKeyLength, key.count)
            }
        }
        self.map = map
        self.maxKeyLength = maxKeyLength
    }

    /// 合并词典（短语优先：靠后的词典覆盖同键条目）。
    ///
    /// OpenCC 语义：词组/字符在同一遍最长匹配中竞争，短语条目遮蔽字符条目
    /// （保证 `乾隆`、`壺裏乾坤` 等短语不被字符级首候选误转）。
    init(merging dictionaries: [PhraseDictionary]) {
        var map: [String: String] = [:]
        var maxKeyLength = 0
        for dictionary in dictionaries {
            for (key, value) in dictionary.map {
                map[key] = value
            }
            maxKeyLength = max(maxKeyLength, dictionary.maxKeyLength)
        }
        self.map = map
        self.maxKeyLength = maxKeyLength
    }

    /// 词组级最长匹配转换。
    func convert(_ text: String) -> String {
        guard !map.isEmpty, !text.isEmpty else { return text }
        let chars = Array(text)
        var out = String()
        out.reserveCapacity(text.utf8.count)
        var index = 0
        while index < chars.count {
            let upper = min(maxKeyLength, chars.count - index)
            var matched = false
            if upper >= 1 {
                for length in stride(from: upper, through: 1, by: -1) {
                    let candidate = String(chars[index ..< (index + length)])
                    if let replacement = map[candidate] {
                        out += replacement
                        index += length
                        matched = true
                        break
                    }
                }
            }
            if !matched {
                out.append(chars[index])
                index += 1
            }
        }
        return out
    }
}

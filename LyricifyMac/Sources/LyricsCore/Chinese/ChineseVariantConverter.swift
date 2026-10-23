import Foundation

/// 简繁转换目标地区（S7 D5：`tw`（默认）| `hk`）。
public enum ChineseRegion: String, Codable, Sendable {
    /// 台湾正体（OpenCC `s2twp` 语义）。
    case tw
    /// 香港（OpenCC `s2hk` 语义）。
    case hk
}

/// 简繁转换服务（词组级，S7 D5：纯字符映射不可接受）。
public protocol ChineseVariantConverting {
    /// 繁→简（OpenCC `t2s` 族，词组级）。
    func toSimplified(_ text: String) -> String
    /// 简→繁（`tw`→`s2twp`，`hk`→`s2hk`，词组级）。
    func toTraditional(_ text: String, region: ChineseRegion) -> String
}

/// OpenCC 官方词典驱动的转换器（S7 D15 选型备案：自研等价实现 + vendored 官方词典）。
///
/// 词典数据：OpenCC 官方词典（Apache-2.0，随包分发；About 页须附许可证）。
/// 转换链与 OpenCC 官方配置语义一致（短语与字符合并单遍最长匹配、短语优先）：
/// - `t2s`：TSPhrases + TSCharacters（合并）；
/// - `s2twp`：(STPhrases + STCharacters) → (TWPhrases + TWVariants)；
/// - `s2hk`：(STPhrases + STCharacters) → (HKPhrases + HKVariants)。
public final class OpenCCChineseConverter: ChineseVariantConverting {
    /// 共享实例（词典只加载一次）。
    public static let shared = OpenCCChineseConverter()

    private let t2s: PhraseDictionary
    private let s2t: PhraseDictionary
    private let tw: PhraseDictionary
    private let hk: PhraseDictionary

    /// 从指定 bundle 加载词典（默认模块资源）。
    init(bundle: Bundle = .module) {
        func load(_ name: String) -> PhraseDictionary {
            guard let url = bundle.url(
                forResource: name,
                withExtension: "txt",
                subdirectory: "OpenCC"
            ) else {
                return PhraseDictionary(contentsOf: URL(fileURLWithPath: "/dev/null"))
            }
            return PhraseDictionary(contentsOf: url)
        }
        // 合并顺序：字符在前、短语在后（短语优先覆盖）。
        t2s = PhraseDictionary(merging: [load("TSCharacters"), load("TSPhrases")])
        s2t = PhraseDictionary(merging: [load("STCharacters"), load("STPhrases")])
        tw = PhraseDictionary(merging: [load("TWVariants"), load("TWPhrases")])
        hk = PhraseDictionary(merging: [load("HKVariants"), load("HKPhrases")])
    }

    public func toSimplified(_ text: String) -> String {
        t2s.convert(text)
    }

    public func toTraditional(_ text: String, region: ChineseRegion) -> String {
        let base = s2t.convert(text)
        switch region {
        case .tw:
            return tw.convert(base)
        case .hk:
            return hk.convert(base)
        }
    }
}

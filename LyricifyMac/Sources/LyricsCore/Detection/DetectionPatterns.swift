import Foundation

/// 判型正则（S1 §3 原样移植；选项等价 `Multiline|Compiled|CultureInvariant`）。
///
/// > Important: 本组正则是 `detectType` 的唯一权威（S7 D9 判型/解析双轨制）。
/// > 解析器的宽容解析不得反向影响判型。
enum DetectionPatterns {
    /// LRC 行：行首一个或多个 `[mm:ss(.ddd|:dd|:ddd)?]` 时间戳。
    static let lrc = "^[ \\t]*(?:\\[\\d+:\\d{1,2}(?:[.:]\\d{1,3})?\\])+[^\\r\\n]*"
    /// KRC 行：`[a,b]<x,y,z>` 词块形态。
    static let krc = "^[ \\t]*\\[\\d+,\\d+\\]<-?\\d+,\\d+,\\d+>[^\\r\\n]*"
    /// YRC 行：`[a,b](x,y,n)` 三元组词块形态。
    static let yrc = "^[ \\t]*\\[\\d+,\\d+\\]\\(-?\\d+,\\d+,\\d+\\)[^\\r\\n]*"
    /// QRC 行：`[a,b]` 行头 + `(x,y)` 二元组词块形态。
    static let qrc = "^[ \\t]*\\[\\d+,\\d+\\][^\\r\\n]*\\(-?\\d+,\\d+\\)[^\\r\\n]*"
    /// LyricifySyllable 行：`[3]`–`[8]` 单数字行标 + `(x,y)` 词块形态。
    static let lyricifySyllable = "^[ \\t]*\\[\\d+\\][^\\r\\n]*\\(-?\\d+,\\d+\\)[^\\r\\n]*"
    /// QRC XML 大包（ignoreCase）：`<Lyric_1 ... LyricContent=`。
    static let qrcFull = "<Lyric_1\\b[^>]*\\bLyricContent\\s*="
    /// 任意逐字时序标记（用于区分逐字行与 LyricifyLines 行形态）。
    static let anySyllableTiming = "(?:\\(-?\\d+,\\d+(?:,\\d+)?\\)|<-?\\d+,\\d+,\\d+>)"

    /// 预编译正则缓存（Compiled 语义）。
    static let lrcRegex = compile(lrc)
    /// 见 ``lrc``。
    static let krcRegex = compile(krc)
    /// 见 ``yrc``。
    static let yrcRegex = compile(yrc)
    /// 见 ``qrc``。
    static let qrcRegex = compile(qrc)
    /// 见 ``lyricifySyllable``。
    static let lyricifySyllableRegex = compile(lyricifySyllable)
    /// 见 ``qrcFull``。
    static let qrcFullRegex = compile(qrcFull, options: [.caseInsensitive])
    /// 见 ``anySyllableTiming``。
    static let anySyllableTimingRegex = compile(anySyllableTiming)
    /// LyricifyLines 行形态：`[起始ms,结束ms]文本`（不含逐字时序；S7 A9 待批推导式）。
    static let lyricifyLinesFormRegex = compile("^[ \\t]*\\[\\d+,\\d+\\][^\\r\\n]*")

    private static func compile(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression {
        // 正则来自 S1 §3 事实规格，编译失败属实现缺陷。
        try! NSRegularExpression(pattern: pattern, options: options.union([.anchorsMatchLines]))
    }
}

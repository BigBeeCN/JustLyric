/// 时间换算标准（S7 D17/A6：round-half-away-from-zero 为全局换算标准）。
public enum Timing {
    /// 秒（浮点）→ 毫秒，round-half-away-from-zero。
    /// - Parameter seconds: 秒。
    /// - Returns: 毫秒。
    public static func milliseconds(fromSeconds seconds: Double) -> Int {
        Int((seconds * 1000).rounded())
    }

    /// 分:秒(.分数) 时间戳 → 毫秒（解析器宽容共用，S7 D9/A9：分数 1–4 位，右侧补零/截断到 3 位）。
    /// - Parameters:
    ///   - minutes: 分。
    ///   - seconds: 秒。
    ///   - fractionDigits: 分数位字符串（可空）。
    /// - Returns: 毫秒；参数非法时为 `nil`。
    public static func milliseconds(minutes: Int, seconds: Int, fractionDigits: String?) -> Int? {
        guard minutes >= 0, seconds >= 0 else { return nil }
        var fraction = fractionDigits ?? ""
        if fraction.count > 3 {
            fraction = String(fraction.prefix(3)) // 截断（A9：[00:05.0000] → 000）
        }
        while fraction.count < 3 {
            fraction.append("0") // 右侧补零：.05 → 050ms
        }
        guard let fractionMs = Int(fraction) else { return nil }
        return (minutes * 60 + seconds) * 1000 + fractionMs
    }
}

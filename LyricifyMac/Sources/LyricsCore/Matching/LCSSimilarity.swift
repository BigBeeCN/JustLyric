/// LCS 相似度（S2 §2.2 步骤 9）。
///
/// `ComputeTextSame(a,b,isCase:)` = LCS 长度 ÷ max(长度) × 100，保留 2 位小数。
/// - Parameters:
///   - a: 文本 a。
///   - b: 文本 b。
///   - isCase: `true` 区分大小写；`false` 先转小写再比较。
/// - Returns: 相似度百分比（0–100）。
public func ComputeTextSame(_ a: String, _ b: String, isCase: Bool) -> Double {
    let charsA = Array(isCase ? a : a.lowercased())
    let charsB = Array(isCase ? b : b.lowercased())
    guard !charsA.isEmpty, !charsB.isEmpty else { return 0 }
    let lcsLength = longestCommonSubsequenceLength(charsA, charsB)
    let value = Double(lcsLength) / Double(max(charsA.count, charsB.count)) * 100
    return (value * 100).rounded() / 100
}

/// 最长公共子序列长度（滚动数组 DP，O(n×m)）。
func longestCommonSubsequenceLength(_ a: [Character], _ b: [Character]) -> Int {
    var previous = [Int](repeating: 0, count: b.count + 1)
    var current = [Int](repeating: 0, count: b.count + 1)
    for i in 1 ... a.count {
        for j in 1 ... b.count {
            if a[i - 1] == b[j - 1] {
                current[j] = previous[j - 1] + 1
            } else {
                current[j] = max(previous[j], current[j - 1])
            }
        }
        swap(&previous, &current)
        current = [Int](repeating: 0, count: b.count + 1)
    }
    return previous[b.count]
}

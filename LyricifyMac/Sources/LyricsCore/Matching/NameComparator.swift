import Foundation

/// 曲名比较（S2 §2.2；D2 acoustic→VeryHigh、D3 positionalMatch 定义）。
///
/// - Parameters:
///   - a: 曲名 a。
///   - b: 曲名 b。
/// - Returns: 档位；任一为空时为 `nil`。
public func CompareName(_ a: String, _ b: String) -> NameMatch? {
    guard !a.isEmpty, !b.isEmpty else { return nil }
    let x = NormalizeName(a)
    let y = NormalizeName(b)

    // 步骤 2：归一化后相等 → Perfect。
    if x == y {
        return .perfect
    }

    // 步骤 3：acoustic version → acoustic 后再比（D2：归一后相等由步骤 4 分支接住 → VeryHigh）。
    let acSuffix = "acoustic version"
    let acx = x.replacingOccurrences(of: acSuffix, with: "acoustic")
    let acy = y.replacingOccurrences(of: acSuffix, with: "acoustic")

    // 步骤 4：DashToParen（D24 字面移植：T(s) = s.Replace(" - ", " (").Trim() + ")"，无条件补 ")"）。
    if dashToParen(acx) == dashToParen(acy) {
        return .veryHigh
    }

    // 步骤 5：SpecialCompare（D23：恰单边带 `(k` 且去该后缀后与另一方全等；双边均带不命中）→ VeryHigh。
    if specialCompare(acx, acy) {
        return .veryHigh
    }

    // 步骤 6：SingleSpecial（D23：双边均含 `(k` 且去标记基名相等）/
    //          DuoSpecial（一侧 feat|with、另一侧 explicit，基名相等）→ High。
    if duoOrSingleSpecial(acx, acy) {
        return .high
    }

    // 步骤 7：BracketsCompare（单边带括号、去括号后与另一方全等）→ Medium。
    if bracketsCompare(acx, acy) {
        return .medium
    }

    // 步骤 8：等长字符位置命中率（D3：仅等长、逐位、已小写归一）→ High。
    if positionalMatch(acx, acy) {
        return .high
    }

    // 步骤 9：LCS 相似度阶梯（严格大于）。
    return NameComparatorTier.tier(forTextSimilarity: ComputeTextSame(acx, acy, isCase: true))
}

/// 步骤 9 阶梯（独立可测，S6 §2.3-2 边界）。
public enum NameComparatorTier {
    /// LCS 相似度 → 档位（`>90 VeryHigh | >80 High | >68 Medium | >55 Low | else NoMatch`）。
    /// - Parameter similarity: `ComputeTextSame` 结果（0–100）。
    /// - Returns: 档位。
    public static func tier(forTextSimilarity similarity: Double) -> NameMatch {
        switch similarity {
        case let value where value > 90: .veryHigh
        case let value where value > 80: .high
        case let value where value > 68: .medium
        case let value where value > 55: .low
        default: .noMatch
        }
    }
}

/// DashToParen 变换（S2 §2.2 步骤 4；D24 字面移植：`T(s) = (s.Replace(" - ", " (").Trim() + ")")`，无条件追加）。
private func dashToParen(_ s: String) -> String {
    s.replacingOccurrences(of: " - ", with: " (")
        .trimmingCharacters(in: .whitespaces) + ")"
}

/// SpecialCompare 键集（S2 §2.2 步骤 5）。
private let specialKeys = ["deluxe", "explicit", "special edition", "bonus track", "feat", "with"]

/// 去掉 `(key…)` 后缀后的主体（找不到返回 nil；结果去首尾空白）。
private func strippingParenSuffix(_ s: String, key: String) -> String? {
    guard let open = s.range(of: "(" + key) else { return nil }
    let result = if let close = s[open.upperBound...].firstIndex(of: ")") {
        String(s[..<open.lowerBound]) + String(s[s.index(after: close)...])
    } else {
        String(s[..<open.lowerBound])
    }
    return result.trimmingCharacters(in: .whitespaces)
}

/// 步骤 5（D23）：恰单边带 `(k` 且去掉该后缀后与另一方全等；双边均带不命中。
private func specialCompare(_ x: String, _ y: String) -> Bool {
    for key in specialKeys {
        let marker = "(" + key
        let leftHas = x.contains(marker)
        let rightHas = y.contains(marker)
        guard leftHas != rightHas else { continue } // 双边均带不命中（D23）
        if leftHas, let stripped = strippingParenSuffix(x, key: key), stripped == y {
            return true
        }
        if rightHas, let stripped = strippingParenSuffix(y, key: key), stripped == x {
            return true
        }
    }
    return false
}

/// 去标记基名（D23 实测：标记前缀去尾空白）。
private func baseBeforeMarker(_ s: String, key: String) -> String? {
    guard let open = s.range(of: "(" + key) else { return nil }
    return String(s[..<open.lowerBound]).trimmingCharacters(in: .whitespaces)
}

/// 步骤 6（D23）：SingleSpecial（双边均含 `(feat|with` 且基名相等）/
/// DuoSpecial（一侧 feat|with、另一侧 explicit，基名相等）。
private func duoOrSingleSpecial(_ x: String, _ y: String) -> Bool {
    for key in ["feat", "with"] {
        // SingleSpecial：双边同名标记、基名相等（D23 实测语义）。
        if let baseX = baseBeforeMarker(x, key: key),
           let baseY = baseBeforeMarker(y, key: key),
           baseX == baseY
        {
            return true
        }
        // DuoSpecial：feat|with 与 explicit 各带一个、基名相等。
        if let baseX = baseBeforeMarker(x, key: key),
           let baseY = baseBeforeMarker(y, key: "explicit"),
           baseX == baseY
        {
            return true
        }
        if let baseX = baseBeforeMarker(x, key: "explicit"),
           let baseY = baseBeforeMarker(y, key: key),
           baseX == baseY
        {
            return true
        }
    }
    return false
}

/// 步骤 7：单边带括号、去括号后与另一方全等。
private func bracketsCompare(_ x: String, _ y: String) -> Bool {
    func stripped(_ s: String) -> String? {
        guard let open = s.firstIndex(of: "("), let close = s[open...].firstIndex(of: ")") else {
            return nil
        }
        return (String(s[..<open]) + String(s[s.index(after: close)...]))
            .trimmingCharacters(in: .whitespaces)
    }
    if let sx = stripped(x), sx == y {
        return true
    }
    if let sy = stripped(y), sy == x {
        return true
    }
    return false
}

/// 步骤 8（D3）：仅等长启用；ratio = 逐位相等数÷长度。
private func positionalMatch(_ x: String, _ y: String) -> Bool {
    let ax = Array(x)
    let ay = Array(y)
    guard ax.count == ay.count, !ax.isEmpty else { return false }
    let matches = zip(ax, ay).filter { $0 == $1 }.count
    let ratio = Double(matches) / Double(ax.count)
    let length = ax.count
    return (ratio >= 0.8 && length >= 4) || (ratio >= 0.5 && (2 ... 3).contains(length))
}

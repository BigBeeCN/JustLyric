/// 歌手比较（S2 §2.3；D4：单档位，a=本地曲目艺人、b=候选结果艺人；n=A 侧命中数）。
///
/// - Parameters:
///   - a: 本地曲目艺人数组（`TrackRef.artists`）。
///   - b: 候选结果艺人数组。
/// - Returns: 档位（规则 1–9 顺序短路）。
public func CompareArtist(_ a: [String], _ b: [String]) -> ArtistMatch? {
    // 预处理：去空、lowercase、繁→简（NormalizeName 覆盖）。
    let na = a.map(NormalizeName).filter { !$0.isEmpty }
    let nb = b.map(NormalizeName).filter { !$0.isEmpty }
    guard !na.isEmpty, !nb.isEmpty else { return nil }
    let n = na.filter { nb.contains($0) }.count

    // 规则 1：n == A.count 且两侧数量相等 → Perfect。
    if n == na.count && na.count == nb.count {
        return .perfect
    }
    // 规则 2：(n+1 >= A.count 且 A.count >= 2) 或 (A.count > 6 且 n/A.count > 0.8) → VeryHigh。
    if (n + 1 >= na.count && na.count >= 2)
        || (na.count > 6 && Double(n) / Double(na.count) > 0.8)
    {
        return .veryHigh
    }
    // 规则 3：n==1 且 A.count==1 且 B.count==2 → High。
    if n == 1, na.count == 1, nb.count == 2 {
        return .high
    }
    // 规则 4：A.count > 5 且 B[0] 含 "Various"/"群星" → VeryHigh。
    if na.count > 5, nb[0].contains("various") || nb[0].contains("群星") {
        return .veryHigh
    }
    // 规则 5：A.count > 7 且 B.count > 7 且 n/A.count > 0.66 → High。
    if na.count > 7, nb.count > 7, Double(n) / Double(na.count) > 0.66 {
        return .high
    }
    // 规则 6：单 A、多 B，A[0] 前缀命中或长子串包含 → High。
    if na.count == 1, nb.count > 1,
       na[0].hasPrefix(nb[0]) || (nb[0].count > 3 && na[0].contains(nb[0]))
    {
        return .high
    }
    // 规则 7：单 A、多 B，A[0] 包含 B[0] → Medium。
    if na.count == 1, nb.count > 1, nb[0].count > 1, na[0].contains(nb[0]) {
        return .medium
    }
    // 规则 8：n==1 且 A.count==1 且 B.count>=3 → Medium。
    if n == 1, na.count == 1, nb.count >= 3 {
        return .medium
    }
    // 规则 9：n >= 2 → Low；否则 NoMatch。
    if n >= 2 {
        return .low
    }
    return .noMatch
}

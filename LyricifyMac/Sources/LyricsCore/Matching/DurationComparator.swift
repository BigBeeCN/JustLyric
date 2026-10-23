/// 时长比较（S2 §2.4）。
///
/// - Parameters:
///   - d1: 时长 1（毫秒）。
///   - d2: 时长 2（毫秒）。
/// - Returns: 档位；任一为 `nil`/0 时为 `nil`。
public func CompareDuration(_ d1: Int?, _ d2: Int?) -> DurationMatch? {
    guard let d1, let d2, d1 != 0, d2 != 0 else { return nil }
    let diff = abs(d1 - d2)
    switch diff {
    case 0: return .perfect
    case ..<300: return .veryHigh
    case ..<700: return .high
    case ..<1500: return .medium
    case ..<3500: return .low
    default: return .noMatch
    }
}

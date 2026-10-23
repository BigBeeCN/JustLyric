/// 源错误（适配器统一错误面）。
public enum LyricsSourceError: Error, Sendable, Equatable {
    /// 无结果（S7 D26：两字段皆缺且非纯音乐；2xx 空 lyrics 等）。
    case noResult
    /// 令牌过期（S2 §1.1：401 → `isTokenExpired` 提示）。
    case tokenExpired
    /// HTTP 状态码异常。
    case httpStatus(Int)
    /// 传输层错误（描述化以保 Sendable/Equatable）。
    case transport(String)
}

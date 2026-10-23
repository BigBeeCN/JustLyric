/// 歌词源标识（S2 §1）。
///
/// > Important: 插件位只留协议（S0 §3-2 红线）：核心仓库仅实现
/// > `.lrclib`/`.appleTTML`/`.localFiles` 三源；`.plugin` 由第三方适配器提供，
/// > 责任由插件作者承担。
public enum SourceID: Hashable, Sendable {
    /// LRCLIB 开放 API。
    case lrclib
    /// Apple Music TTML（用户自持 MediaUserToken）。
    case appleTTML
    /// 本地歌词文件。
    case localFiles
    /// 插件源（稳定标识符由插件提供）。
    case plugin(String)

    /// 从稳定标识符还原（缓存/设置映射用）。
    /// - Parameter identifier: 稳定标识符。
    public init?(identifier: String) {
        switch identifier {
        case "lrclib": self = .lrclib
        case "apple_ttml": self = .appleTTML
        case "local_files": self = .localFiles
        default:
            guard identifier.hasPrefix("plugin:") else { return nil }
            self = .plugin(String(identifier.dropFirst("plugin:".count)))
        }
    }

    /// 稳定标识符（用于缓存 `source` 列与持久化）。
    public var identifier: String {
        switch self {
        case .lrclib: "lrclib"
        case .appleTTML: "apple_ttml"
        case .localFiles: "local_files"
        case let .plugin(id): "plugin:\(id)"
        }
    }
}

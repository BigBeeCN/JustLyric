import Foundation

/// UA 头单点（S7 D27 #1 / D47 命名门禁：产品名/版本 + github.com/组织/仓库 模板）。
///
/// > Note: 产品名/UA 禁含工作名（D47 新红线）；工作名仅限内部。
/// > 发版前 P5 检查项单点替换版本号（``make(version:org:repo:)``）。
public enum UserAgent {
    /// 版本占位（发版前替换）。
    public static let versionPlaceholder = "0.0.1"
    /// 组织占位（发版前替换）。
    public static let orgPlaceholder = "BigBeeCN"
    /// 仓库占位（发版前替换）。
    public static let repoPlaceholder = "JustLyric"

    /// 构造 UA 头。
    /// - Parameters:
    ///   - version: 版本。
    ///   - org: 组织。
    ///   - repo: 仓库。
    /// - Returns: UA 头值。
    public static func make(
        version: String = versionPlaceholder,
        org: String = orgPlaceholder,
        repo: String = repoPlaceholder
    ) -> String {
        "JustLyric/\(version) (github.com/\(org)/\(repo))"
    }

    /// 当前 UA（占位态；P5 发版检查项负责定稿）。
    public static let current = make()
}

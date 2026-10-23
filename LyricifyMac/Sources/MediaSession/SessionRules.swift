import Foundation

/// 会话分类规则（S3 §4）。
public enum SessionRules {
    /// 首方规则表（bundle id 小写 → 分类；id 字面量属常数类 D27 #3 免报）。
    public static let known: [String: SessionKind] = [
        // 已知音乐 app（S3 §4）
        "com.spotify.client": .musicApp,
        "com.apple.music": .musicApp,
        "com.coppertino.vox": .musicApp,
        "com.netease.163music": .musicApp,
        "com.tencent.qqmusic": .musicApp,
        "app.cider.cider": .musicApp,
        "com.swinsian.swinsian": .musicApp,
        "com.foobar2000.mac": .musicApp,
        // 浏览器（默认不显示歌词）
        "com.google.chrome": .browser,
        "com.apple.safari": .browser,
        "org.mozilla.firefox": .browser,
        "com.microsoft.edgemac": .browser,
        // 视频
        "com.apple.tv": .video,
        "com.google.chrome.canary": .browser,
    ]

    /// bundle id → 分类（小写归一；未知 → `.unknown`）。
    /// - Parameter bundleID: bundle id。
    /// - Returns: 分类。
    public static func kind(forBundleID bundleID: String) -> SessionKind {
        known[bundleID.lowercased()] ?? .unknown
    }

    /// 分类默认是否取词/显示（S3 §4：浏览器/视频/游戏默认不显示）。
    /// - Parameter kind: 分类。
    /// - Returns: 默认启用。
    public static func defaultEnabled(for kind: SessionKind) -> Bool {
        kind == .musicApp
    }
}

/// 会话启用策略（S3 §4：`IsEnabledByDefault`/`IsEnabledByUser`；未知 app 首次询问）。
public struct SessionPolicy: Sendable, Equatable {
    /// 用户选择记忆（bundle id → 是否启用）。
    public private(set) var userChoices: [String: Bool]

    /// 创建策略。
    /// - Parameter userChoices: 已记忆选择。
    public init(userChoices: [String: Bool] = [:]) {
        self.userChoices = userChoices
    }

    /// 决策。
    /// - Parameters:
    ///   - bundleID: bundle id。
    ///   - kind: 分类。
    /// - Returns: `nil` = 需要询问用户（未知 app 首次，S3 §4）。
    public func decision(forBundleID bundleID: String, kind: SessionKind) -> Bool? {
        let key = bundleID.lowercased()
        if let choice = userChoices[key] {
            return choice
        }
        if kind == .unknown {
            return nil
        }
        return SessionRules.defaultEnabled(for: kind)
    }

    /// 记住用户选择。
    /// - Parameters:
    ///   - bundleID: bundle id。
    ///   - enabled: 是否启用。
    public mutating func remember(bundleID: String, enabled: Bool) {
        userChoices[bundleID.lowercased()] = enabled
    }
}

import Foundation

/// 更新设置（S5 §2 v1：Sparkle 2 + GitHub Releases）。
///
/// > Note: `SUFeedURL`/UA 定稿依赖委托方提供的 org/repo（D27 #1）——
/// > Sparkle 依赖接入随发版管线，本层为配置与检查抽象。
public struct UpdateSettings: Codable, Equatable, Sendable {
    /// 更新源（appcast URL；占位——随 UA 定稿替换）。
    public var feedURL: String
    /// 自动检查开关。
    public var checkAutomatically: Bool

    /// 创建设置。
    public init(feedURL: String = "", checkAutomatically: Bool = true) {
        self.feedURL = feedURL
        self.checkAutomatically = checkAutomatically
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        feedURL = try c.decodeIfPresent(String.self, forKey: .feedURL) ?? ""
        checkAutomatically = try c.decodeIfPresent(Bool.self, forKey: .checkAutomatically) ?? true
    }
}

/// 更新检查抽象（Sparkle 适配随发版管线接入）。
public struct UpdateChecker: Sendable {
    /// 设置。
    public var settings: UpdateSettings

    /// 创建检查器。
    /// - Parameter settings: 设置。
    public init(settings: UpdateSettings = UpdateSettings()) {
        self.settings = settings
    }

    /// 是否可检查（feed URL 已定稿）。
    public var canCheck: Bool {
        !settings.feedURL.isEmpty
    }
}

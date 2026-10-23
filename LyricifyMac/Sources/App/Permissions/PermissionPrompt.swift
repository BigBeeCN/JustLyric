import Foundation
import MediaSession

/// 应用生命周期（S5 §2：单实例/启动/退出清理）。
public enum AppLifecycle {
    /// 单实例决策（S5 §2）。
    /// - Parameters:
    ///   - bundleID: 自身 bundle id。
    ///   - running: 已运行实例数（含自身）。
    /// - Returns: 应退出让位（已有实例时 true）。
    public static func shouldYieldToExisting(bundleID: String, running: Int) -> Bool {
        running > 1
    }

    /// 启动日志（os.Logger 本地，S5 §4：零遥测）。
    /// - Parameter mode: 当前集成模式。
    /// - Returns: 启动描述。
    public static func startupDescription(mode: IntegrationMode) -> String {
        "JustLyric 启动；集成模式=\(mode.rawValue)（本地日志，无上传）"
    }
}

/// 权限引导（S3 §7；[红线-P2] 引导文案本地化、无网络回传）。
public struct PermissionPrompt: Equatable, Sendable {
    /// 引导类型。
    public enum Kind: String, Sendable, Equatable {
        /// Automation（AppleEvents）授权。
        case automation
        /// MediaRemote 降级提示。
        case mediaRemoteDegraded
    }

    /// 当前需要的引导（nil=无需）。
    public var pending: Kind?

    /// 创建引导。
    /// - Parameter pending: 待处理项。
    public init(pending: Kind? = nil) {
        self.pending = pending
    }

    /// 由集成模式/授权态推导引导（S3 §7）。
    /// - Parameters:
    ///   - mode: 集成模式。
    ///   - automationDenied: Automation 被拒。
    /// - Returns: 引导。
    public static func resolve(mode: IntegrationMode, automationDenied: Bool) -> PermissionPrompt {
        if automationDenied, PermissionGuide.shouldGuideToSettings(.denied) {
            return PermissionPrompt(pending: .automation)
        }
        if mode == .directOnly {
            return PermissionPrompt(pending: .mediaRemoteDegraded)
        }
        return PermissionPrompt()
    }

    /// 引导文案 key（App 层本地化）。
    /// - Parameter kind: 类型。
    /// - Returns: 文案 key。
    public func textKey(for kind: Kind) -> String {
        switch kind {
        case .automation: PermissionGuide.automationDeniedNoticeKey
        case .mediaRemoteDegraded: PermissionGuide.degradedNoticeKey
        }
    }
}

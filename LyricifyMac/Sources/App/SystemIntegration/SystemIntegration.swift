import AppKit
import ServiceManagement

/// 单实例（S5 §2：`NSRunningApplication` 激活已有实例）。
public enum SingleInstance {
    /// 是否已有运行实例（不含自身语义由调用方给 bundleId）。
    /// - Parameter bundleIdentifier: bundle id。
    /// - Returns: 已有实例列表。
    public static func existingInstances(bundleIdentifier: String) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    }

    /// 激活已有实例。
    /// - Parameter instance: 实例。
    public static func activate(_ instance: NSRunningApplication) {
        instance.activate() // macOS 14+：activate(options:) 已弃用
    }
}

/// 开机自启（S5 §2：`SMAppService.mainApp`）。
public enum LoginItem {
    /// 状态。
    public enum Status: String, Sendable, Equatable {
        /// 已注册。
        case enabled
        /// 未注册。
        case disabled
        /// 需要用户手动操作（系统设置）。
        case requiresApproval
    }

    /// 当前状态。
    public static func status() -> Status {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .disabled
        }
    }

    /// 注册/注销。
    /// - Parameter enable: 开关。
    /// - Throws: 系统错误。
    public static func setEnabled(_ enable: Bool) throws {
        if enable {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// 睡眠策略（S5 §2：`prevent_sleep_fullscreen_only`）。
public struct SleepPolicy: Equatable, Sendable {
    /// 仅全屏时防休眠（默认 true）。
    public var preventSleepFullscreenOnly: Bool

    /// 创建策略。
    /// - Parameter preventSleepFullscreenOnly: 仅全屏防休眠。
    public init(preventSleepFullscreenOnly: Bool = true) {
        self.preventSleepFullscreenOnly = preventSleepFullscreenOnly
    }

    /// 是否应防休眠。
    /// - Parameters:
    ///   - isFullscreenActive: 全屏展示中。
    ///   - anyPlayback: 任意播放中。
    /// - Returns: 开启防休眠。
    public func shouldPreventSleep(isFullscreenActive: Bool, anyPlayback: Bool) -> Bool {
        guard anyPlayback else { return false }
        return preventSleepFullscreenOnly ? isFullscreenActive : true
    }
}

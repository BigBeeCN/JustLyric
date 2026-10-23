import Foundation
import LyricsCore
import MediaSession
import Sources

/// 应用组装器（M4-10：设置/窗口/生命周期/权限引导/日志总装）。
public final class AppCoordinator {
    /// 设置存储。
    public let settingsStore: SettingsStore
    /// 窗口管理。
    public private(set) var windowManager = WindowManager()
    /// 聚合器（M2 交付）。
    public let aggregator = NowPlayingAggregator()
    /// 编排器（M2 交付）。
    public let provider: LyricsProvider
    /// 权限引导。
    public private(set) var permissionPrompt = PermissionPrompt()

    /// 创建组装器。
    /// - Parameter settingsStore: 设置存储。
    public init(settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
        provider = LyricsProvider(adapters: [LRCLIBAdapter()])
    }

    /// 启动（生命周期 + 权限引导 + 显示面恢复，S5 §3/§2）。
    /// - Parameters:
    ///   - mode: 集成模式。
    ///   - automationDenied: Automation 被拒。
    /// - Returns: 启动日志描述（os.Logger 本地）。
    @discardableResult
    public func start(mode: IntegrationMode, automationDenied: Bool) -> String {
        let settings = settingsStore.load()
        windowManager = WindowManager(memory: [
            "desktopLyrics": !settings.desktopLyrics.isLocked || true,
            "menuBar": true,
            "island": false,
            "fullscreen": false,
        ])
        permissionPrompt = PermissionPrompt.resolve(
            mode: mode,
            automationDenied: automationDenied
        )
        return AppLifecycle.startupDescription(mode: mode)
    }

    /// 显示面开关（记忆持久化，S6 §5 手测项）。
    /// - Parameters:
    ///   - surface: 显示面。
    ///   - on: 开关。
    public func setSurface(_ surface: DisplaySurface, on: Bool) {
        windowManager.setEnabled(surface, on: on)
    }
}

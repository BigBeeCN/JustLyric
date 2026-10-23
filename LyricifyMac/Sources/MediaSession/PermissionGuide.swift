import Foundation
import LyricsCore

/// 系统集成模式（S3 §7 降级语义）。
public enum IntegrationMode: String, Sendable, Equatable {
    /// 完整：MediaRemote + 直连 + 分发通知。
    case full
    /// 降级：仅直连 + 分发通知（MediaRemote 加载失败）。
    case directOnly
}

/// 权限与降级（S3 §7；[红线-P2] 引导文案本地化、无网络回传）。
public enum PermissionGuide {
    /// Automation 设置页（`System Settings → Privacy & Security → Automation`）。
    public static let automationSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    )!

    /// 降级提示文案 key（App 层本地化；S3 §7 设置页提示）。
    public static let degradedNoticeKey = "settings.degraded_media_remote"

    /// Automation 未授权引导文案 key。
    public static let automationDeniedNoticeKey = "settings.automation_authorization_required"

    /// 由 MediaRemote 可用性决定集成模式。
    /// - Parameter mediaRemoteAvailable: `MediaRemoteShim.isAvailable`。
    /// - Returns: 集成模式。
    public static func mode(mediaRemoteAvailable: Bool) -> IntegrationMode {
        mediaRemoteAvailable ? .full : .directOnly
    }

    /// Automation 授权状态（S3 §7）。
    public enum AutomationStatus: String, Sendable, Equatable {
        /// 已授权。
        case authorized
        /// 未决定（首次触发询问）。
        case notDetermined
        /// 被拒绝（引导设置页）。
        case denied
    }

    /// 是否需要引导用户到设置页。
    /// - Parameter status: 授权状态。
    /// - Returns: 需要引导时为 `true`。
    public static func shouldGuideToSettings(_ status: AutomationStatus) -> Bool {
        status == .denied
    }
}

/// 诊断快照（S5 §4：当前会话、时间轴样本、源命中率、延迟生效值）。
public struct DiagnosticSnapshot: Sendable, Equatable {
    /// 当前曲目。
    public var currentTrack: TrackRef?
    /// 时间轴读数（毫秒）。
    public var timelineElapsedMs: Int?
    /// 生效延迟（毫秒，D29 #1 符号约定）。
    public var effectiveLatencyMs: Int?
    /// 源命中计数。
    public var sourceHitCounts: [String: Int]
    /// 集成模式。
    public var mode: IntegrationMode

    /// 创建诊断快照。
    /// - Parameters:
    ///   - currentTrack: 当前曲目。
    ///   - timelineElapsedMs: 时间轴读数。
    ///   - effectiveLatencyMs: 生效延迟。
    ///   - sourceHitCounts: 源命中计数。
    ///   - mode: 集成模式。
    public init(
        currentTrack: TrackRef? = nil,
        timelineElapsedMs: Int? = nil,
        effectiveLatencyMs: Int? = nil,
        sourceHitCounts: [String: Int] = [:],
        mode: IntegrationMode = .full
    ) {
        self.currentTrack = currentTrack
        self.timelineElapsedMs = timelineElapsedMs
        self.effectiveLatencyMs = effectiveLatencyMs
        self.sourceHitCounts = sourceHitCounts
        self.mode = mode
    }
}

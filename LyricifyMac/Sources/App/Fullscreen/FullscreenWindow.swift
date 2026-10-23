import AppKit
import IOKit
import IOKit.pwr_mgt
import RenderKit

/// 全屏歌词配置（S4 §5；S7 D35：AdaptiveText 0.5× 下限、进度条底部细条、缩放 1.0、防休眠）。
public struct FullscreenConfig: Sendable {
    /// 进度条显示模式（`progress_bar_display_mode`）。
    public enum ProgressBarMode: String, Sendable {
        /// 底部细条（D35 默认）。
        case bottomThin
        /// 关闭。
        case hidden
    }

    /// 自适应字号（AdaptiveText 拟合）。
    public var adaptiveFontSize = true
    /// 自适应下限比（D35：0.5×）。
    public var adaptiveMinScale: Double = 0.5
    /// 进度条模式（D35：默认底部细条）。
    public var progressBarMode: ProgressBarMode = .bottomThin
    /// 缩放级别（`zooming_levels`，D35：默认 1.0）。
    public var zoomingLevel: Double = 1.0
    /// 防休眠（S4 §5）。
    public var preventSleep = true
    /// 呼吸点（间奏）。
    public var showBreathingDots = true

    /// 创建配置。
    public init() {}
}

/// 防休眠（S4 §5：`IOPMAssertionCreate`；M4-05 系统集成联动）。
public final class SleepPrevention: @unchecked Sendable {
    private var assertionID: IOPMAssertionID = 0

    /// 创建断言。
    public init() {}

    /// 开始防休眠。
    /// - Returns: 是否成功。
    @discardableResult
    public func start() -> Bool {
        guard assertionID == 0 else { return true }
        var newID: IOPMAssertionID = 0
        let reason = "JustLyric fullscreen lyrics" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &newID
        )
        if result == kIOReturnSuccess {
            assertionID = newID
            return true
        }
        return false
    }

    /// 结束防休眠。
    public func stop() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }
}

/// 全屏歌词窗口（S4 §5）。
public final class FullscreenWindow: NSWindow {
    /// 配置。
    public var config: FullscreenConfig
    /// 防休眠。
    public let sleepPrevention = SleepPrevention()

    /// 创建全屏窗口。
    /// - Parameter config: 配置。
    public init(config: FullscreenConfig = FullscreenConfig()) {
        self.config = config
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.fullScreenPrimary] // 全屏展示（S4 §5）
    }

    /// 拟合字号（AdaptiveText，0.5× 下限，D35）。
    /// - Parameters:
    ///   - text: 文本。
    ///   - width: 可用宽度。
    /// - Returns: 字号。
    public func fittedFontSize(text: String, width: CGFloat) -> CGFloat {
        AdaptiveTextFitting.fittedFontSize(
            text: text,
            baseFont: RenderKit.SnapshotBaseline.font,
            width: width,
            minScale: CGFloat(config.adaptiveMinScale)
        )
    }

    /// 进入全屏展示（开防休眠，S4 §5）。
    public func enterDisplay() {
        if config.preventSleep {
            sleepPrevention.start()
        }
    }

    /// 离开展示（关防休眠）。
    public func exitDisplay() {
        sleepPrevention.stop()
    }
}

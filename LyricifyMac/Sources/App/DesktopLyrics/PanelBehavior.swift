import Foundation

/// 桌面歌词窗行为规则（S5 §3；交互级细节记录见 decisions——双击编辑按 D16 分流）。
///
/// 编辑态窗口行为（D39 提示 #1 验收描述件）：
/// 进入编辑 = **窗口转可激活**（获取焦点）+ 显示细边框与拖拽把手 + 自动隐藏暂停；
/// 退出编辑 = 恢复 `nonactivatingPanel`（不抢焦点）+ 边框隐藏；`isLocked` 时禁止进入编辑。
public struct PanelBehavior: Equatable, Sendable {
    /// 锁定（点击穿透，S5 §3）。
    public var isLocked: Bool
    /// 编辑态（双击进入）。
    public var isEditing: Bool
    /// 自动隐藏（`auto_hide`：停止 5s 后隐藏）。
    public var autoHide: Bool
    /// 进入隐藏（`enter_hide`）。
    public var enterHide: Bool
    /// 全屏时隐藏（`fullscreen_hide`）。
    public var fullscreenHide: Bool

    /// 自动隐藏延迟（秒，S5 §3：停止 5s）。
    public static let autoHideDelaySeconds: TimeInterval = 5

    /// 创建行为。
    public init(
        isLocked: Bool = false,
        isEditing: Bool = false,
        autoHide: Bool = true,
        enterHide: Bool = false,
        fullscreenHide: Bool = true
    ) {
        self.isLocked = isLocked
        self.isEditing = isEditing
        self.autoHide = autoHide
        self.enterHide = enterHide
        self.fullscreenHide = fullscreenHide
    }

    /// 是否点击穿透（S5 §3：锁定后穿透）。
    public var ignoresMouse: Bool {
        isLocked && !isEditing
    }

    /// 双击处理（S5 §3：双击进编辑；锁定时忽略）。
    public mutating func handleDoubleClick() {
        guard !isLocked else { return }
        isEditing.toggle()
    }

    /// 是否应显示编辑边框。
    public var showsEditBorder: Bool {
        isEditing
    }

    /// 自动隐藏判定（S5 §3：停止 5s 后隐藏；编辑态/关闭开关时不隐藏）。
    /// - Parameters:
    ///   - playbackStoppedAt: 停止时刻（nil=未停止）。
    ///   - now: 当前时刻。
    /// - Returns: 应隐藏。
    public func shouldAutoHide(playbackStoppedAt: TimeInterval?, now: TimeInterval) -> Bool {
        guard autoHide, !isEditing, let stoppedAt = playbackStoppedAt else { return false }
        return now - stoppedAt >= Self.autoHideDelaySeconds
    }

    /// 全屏隐藏判定（S5 §3）。
    /// - Parameter isAnyAppFullscreen: 系统存在全屏应用。
    /// - Returns: 应隐藏。
    public func shouldHideOnFullscreen(isAnyAppFullscreen: Bool) -> Bool {
        fullscreenHide && isAnyAppFullscreen
    }
}

/// 屏幕边缘吸附（S5 §3：拖动吸附屏幕边缘）。
public enum EdgeSnap {
    /// 吸附阈值（pt；常数记录免报）。
    public static let snapThreshold: Double = 24

    /// 计算吸附后原点。
    /// - Parameters:
    ///   - proposedOrigin: 拖动后原点。
    ///   - frameSize: 窗口尺寸。
    ///   - screenFrame: 屏幕帧。
    /// - Returns: 吸附后的原点（无吸附返回原值）。
    public static func snap(
        proposedOrigin: CGPoint,
        frameSize: CGSize,
        screenFrame: CGRect
    ) -> CGPoint {
        var origin = proposedOrigin
        let minX = screenFrame.minX
        let maxX = screenFrame.maxX - frameSize.width
        let minY = screenFrame.minY
        let maxY = screenFrame.maxY - frameSize.height

        if abs(Double(origin.x) - Double(minX)) <= snapThreshold {
            origin.x = minX
        }
        if abs(Double(origin.x) - Double(maxX)) <= snapThreshold {
            origin.x = maxX
        }
        if abs(Double(origin.y) - Double(minY)) <= snapThreshold {
            origin.y = minY
        }
        if abs(Double(origin.y) - Double(maxY)) <= snapThreshold {
            origin.y = maxY
        }
        return origin
    }
}

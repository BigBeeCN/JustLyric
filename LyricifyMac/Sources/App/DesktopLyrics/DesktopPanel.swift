import AppKit

/// 桌面歌词窗（S5 §3；S4 §5：nonactivatingPanel/floating/跨 Space）。
///
/// 编辑态行为（D39 提示 #1 描述件）：进入编辑转可激活 + 细边框 + 拖拽把手；
/// 退出恢复 nonactivating；锁定时点击穿透且禁入编辑。
public final class DesktopPanel: NSPanel {
    /// 行为规则。
    public private(set) var behavior: PanelBehavior
    /// 吸附后的原点（测试断言）。
    public private(set) var snappedOrigin: CGPoint = .zero

    /// 创建桌面歌词窗。
    /// - Parameters:
    ///   - contentRect: 内容帧。
    ///   - behavior: 行为初值。
    public init(contentRect: NSRect, behavior: PanelBehavior = PanelBehavior()) {
        self.behavior = behavior
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // 跨 Space（S4 §5）
        applyBehavior()
    }

    /// 双击进入/退出编辑（S5 §3）。
    public func doubleClicked() {
        behavior.handleDoubleClick()
        applyBehavior()
    }

    /// 锁定切换（S5 §3：锁定后穿透）。
    public func setLocked(_ locked: Bool) {
        behavior.isLocked = locked
        applyBehavior()
    }

    /// 拖动结束吸附（S5 §3）。
    /// - Parameters:
    ///   - proposedOrigin: 拟放置原点。
    ///   - screenFrame: 屏幕帧。
    public func dragEnded(proposedOrigin: CGPoint, screenFrame: CGRect) {
        snappedOrigin = EdgeSnap.snap(
            proposedOrigin: proposedOrigin,
            frameSize: frame.size,
            screenFrame: screenFrame
        )
        setFrameOrigin(snappedOrigin)
    }

    /// 应用行为（穿透/编辑边框/焦点形态）。
    private func applyBehavior() {
        ignoresMouseEvents = behavior.ignoresMouse
        styleMask = behavior.isEditing
            ? [.titled, .closable, .resizable, .utilityWindow]
            : [.nonactivatingPanel, .borderless]
        if behavior.isEditing {
            // 编辑态：转可激活 + 细边框（描述件见类注释）。
            if !canBecomeKey { /* NSPanel 默认不可成为 key；编辑态子类覆写见 canBecomeKey */ }
            makeKeyAndOrderFront(nil)
        }
    }

    /// 编辑态允许成为 key（进/出编辑焦点行为，D39 提示 #1）。
    override public var canBecomeKey: Bool {
        behavior.isEditing
    }
}

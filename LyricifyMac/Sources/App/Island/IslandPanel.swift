import AppKit

/// 灵动条面板（S4 §5；D35：无边框、顶部居中、byland 状态机驱动帧）。
public final class IslandPanel: NSPanel {
    /// byland 状态机。
    public let stateMachine = BylandStateMachine()
    private let screenFrame: CGRect
    private let contentWidth: Double

    /// 创建面板。
    /// - Parameters:
    ///   - screenFrame: 屏幕帧。
    ///   - contentWidth: 内容宽度。
    public init(screenFrame: CGRect, contentWidth: Double) {
        self.screenFrame = screenFrame
        self.contentWidth = contentWidth
        let frame = IslandLayout.panelFrame(screenFrame: screenFrame, contentWidth: contentWidth)
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isMovable = false
        // squircle 18pt（D35）：圆角挂内容层（NSWindow 无 cornerRadius 属性）。
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = IslandLayout.cornerRadius
        contentView?.layer?.masksToBounds = true
        stateMachine.onStateChange = { [weak self] state in
            guard let self else { return }
            apply(state: state)
        }
        apply(state: stateMachine.state)
    }

    /// 应用状态帧（展开/半隐藏）。
    /// - Parameter state: byland 状态。
    public func apply(state: BylandStateMachine.State) {
        let full = IslandLayout.panelFrame(screenFrame: screenFrame, contentWidth: contentWidth)
        switch state {
        case .expanded:
            setFrame(full, display: true)
        case .halfHidden:
            setFrame(IslandLayout.halfHiddenFrame(full), display: true)
        }
    }
}

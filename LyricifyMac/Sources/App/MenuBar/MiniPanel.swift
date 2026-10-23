import AppKit

/// 迷你面板（S4 §5：点弹/ESC 关）。
public final class MiniPanel: NSPanel {
    /// 是否已关闭（测试断言）。
    public private(set) var wasDismissedByESC = false

    /// 创建迷你面板。
    /// - Parameter contentRect: 内容尺寸。
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
    }

    /// ESC 关闭（S4 §5）。
    override public func cancelOperation(_ sender: Any?) {
        wasDismissedByESC = true
        orderOut(nil)
    }
}

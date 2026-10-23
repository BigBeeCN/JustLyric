import AppKit

/// 灵动条布局（S4 §5；S7 D35 顶部语义 + D39 四缘增强）。
public enum IslandLayout {
    /// 停靠边（D39：四缘任意吸附为 M5 增强，设置键位预留 `island.dock_edge`）。
    public enum DockEdge: String, CaseIterable, Sendable {
        /// 顶（v1 默认）。
        case top
        /// 底。
        case bottom
        /// 左。
        case left
        /// 右。
        case right
    }

    /// 距边（pt，D35：24）。
    public static let edgeMargin: Double = 24
    /// 距顶（v1 语义别名，D35）。
    public static let topMargin: Double = edgeMargin
    /// 高度（pt，D35：36）。
    public static let height: Double = 36
    /// 圆角（pt，D35：squircle 18）。
    public static let cornerRadius: Double = 18
    /// 最大宽比（D35：≤屏 60%）。
    public static let maxScreenWidthRatio: Double = 0.6

    /// 计算面板帧（默认顶缘；D39 四缘）。
    /// - Parameters:
    ///   - screenFrame: 屏幕帧。
    ///   - contentWidth: 内容期望宽。
    ///   - edge: 停靠边（默认 `.top`，v1 语义）。
    /// - Returns: 面板帧。
    public static func panelFrame(
        screenFrame: CGRect,
        contentWidth: Double,
        edge: DockEdge = .top
    ) -> CGRect {
        let maxWidth = Double(screenFrame.width) * maxScreenWidthRatio
        let width = min(max(0, contentWidth), maxWidth)
        switch edge {
        case .top, .bottom:
            let x = (Double(screenFrame.width) - width) / 2
            let y = edge == .top ? edgeMargin : Double(screenFrame.height) - edgeMargin - height
            return CGRect(x: x, y: y, width: width, height: height)
        case .left, .right:
            let x = edge == .left ? edgeMargin : Double(screenFrame.width) - edgeMargin - height
            return CGRect(x: x, y: (Double(screenFrame.height) - width) / 2, width: height, height: width)
        }
    }

    /// 半隐藏帧（贴边露出一半，D39 语义）。
    /// - Parameters:
    ///   - frame: 全尺寸帧。
    ///   - edge: 停靠边。
    /// - Returns: 半隐藏帧。
    public static func halfHiddenFrame(_ frame: CGRect, edge: DockEdge = .top) -> CGRect {
        var result = frame
        switch edge {
        case .top:
            result.origin.y = frame.origin.y - frame.height / 2
        case .bottom:
            result.origin.y = frame.origin.y + frame.height / 2
        case .left:
            result.origin.x = frame.origin.x - frame.width / 2
        case .right:
            result.origin.x = frame.origin.x + frame.width / 2
        }
        return result
    }
}

import AppKit
import RenderKit

/// 菜单栏控制器（S4 §5；S7 D35：内容=曲名-歌手、超宽 Marquee 复用 M3、点弹迷你面板）。
public final class StatusItemController {
    /// 状态栏项。
    public let statusItem: NSStatusItem
    private let marquee = MarqueeText()
    private var miniPanel: MiniPanel?

    /// 创建控制器。
    /// - Parameter width: 项宽（pt）。
    public init(width: CGFloat = 180) {
        statusItem = NSStatusBar.system.statusItem(withLength: width)
        if let button = statusItem.button {
            marquee.frame = button.bounds
            marquee.autoresizingMask = [.width, .height]
            button.addSubview(marquee)
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    /// 更新内容（D35：曲名-歌手；超宽走 Marquee，30pt/s + 1.5s 驻留）。
    /// - Parameters:
    ///   - title: 曲名。
    ///   - artist: 歌手。
    ///   - reduceMotion: 减弱动态效果。
    public func update(title: String?, artist: String?, reduceMotion: Bool = false) {
        let text = MenuBarMarquee.content(title: title, artist: artist)
        marquee.setText(
            text,
            speedPtsPerSecond: MenuBarMarquee.scrollSpeedPtsPerSecond,
            reduceMotion: reduceMotion,
            dwellSeconds: MenuBarMarquee.dwellSeconds
        )
    }

    /// 点击弹出迷你面板（S4 §5：点弹；ESC 关由 MiniPanel 处理）。
    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        let panel = miniPanel ?? MiniPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 120))
        miniPanel = panel
        if let screen = button.window?.screen {
            let buttonFrame = button.frame
            panel.setFrameTopLeftPoint(
                NSPoint(x: buttonFrame.midX - 130, y: screen.visibleFrame.maxY - 8)
            )
        }
        panel.makeKeyAndOrderFront(nil)
    }
}

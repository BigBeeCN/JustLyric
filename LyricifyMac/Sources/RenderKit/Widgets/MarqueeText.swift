import AppKit

/// 跑马灯文本（S4 §1 MarqueeText：超宽文本跑马灯）。
///
/// ReduceMotion：不滚动（截断显示）。
public final class MarqueeText: NSView {
    private let textLayer = CATextLayer()

    /// 创建跑马灯。
    /// - Parameter font: 字体（默认快照基准 17pt，D30 #4）。
    public init(font: NSFont = SnapshotBaseline.font) {
        super.init(frame: .zero)
        wantsLayer = true
        textLayer.font = font
        textLayer.fontSize = font.pointSize
        layer?.addSublayer(textLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 铺设文本；超宽时滚动（S4 §1）。
    /// - Parameters:
    ///   - text: 文本。
    ///   - speedPtsPerSecond: 滚动速度（pt/s）。
    ///   - reduceMotion: 减弱动态效果。
    ///   - dwellSeconds: 两端驻留秒数（菜单栏 D35：1.5s；0=无驻留原行为）。
    public func setText(
        _ text: String,
        speedPtsPerSecond: Double = 30,
        reduceMotion: Bool = false,
        dwellSeconds: Double = 0
    ) {
        let width = (text as NSString).size(withAttributes: [.font: SnapshotBaseline.font]).width
        textLayer.string = text
        textLayer.frame = CGRect(x: 0, y: 0, width: max(width, bounds.width), height: bounds.height)
        textLayer.removeAllAnimations()

        guard !reduceMotion, width > bounds.width, bounds.width > 0 else { return }
        let travel = width - bounds.width
        let travelSeconds = travel / max(1, speedPtsPerSecond)
        let start = bounds.width / 2
        let end = bounds.width / 2 - travel

        if dwellSeconds > 0 {
            // 驻留模式：关键帧（起点停 → 移动 → 终点停 → 回程）。
            let cycle = (travelSeconds + dwellSeconds) * 2
            let moveRatio = travelSeconds / cycle
            let holdRatio = dwellSeconds / cycle
            let scroll = CAKeyframeAnimation(keyPath: "position.x")
            scroll.values = [start, start, end, end, start]
            scroll.keyTimes = [
                0,
                NSNumber(value: holdRatio),
                NSNumber(value: holdRatio + moveRatio),
                NSNumber(value: holdRatio * 2 + moveRatio),
                1,
            ]
            scroll.duration = cycle
            scroll.repeatCount = .infinity
            textLayer.add(scroll, forKey: "marquee")
            return
        }

        let scroll = CABasicAnimation(keyPath: "position.x")
        scroll.fromValue = start
        scroll.toValue = end
        scroll.duration = travelSeconds
        scroll.autoreverses = true
        scroll.repeatCount = .infinity
        textLayer.add(scroll, forKey: "marquee")
    }
}

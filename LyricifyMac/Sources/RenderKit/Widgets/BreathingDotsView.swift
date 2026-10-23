import AppKit

/// 呼吸点（S4 §1 BreathingDots：间奏呼吸点）。
///
/// ReduceMotion（S4 §3）：呼吸动画关闭为静态点。
public final class BreathingDotsView: NSView {
    private let stack = NSStackView()
    private var dotLayers: [CALayer] = []

    /// 创建呼吸点。
    /// - Parameters:
    ///   - count: 点数（默认 3）。
    ///   - reduceMotion: 减弱动态效果。
    public init(count: Int = 3, reduceMotion: Bool = false) {
        super.init(frame: .zero)
        wantsLayer = true
        for _ in 0 ..< max(1, count) {
            let dot = CALayer()
            dot.cornerRadius = 3
            dot.backgroundColor = NSColor.labelColor.cgColor
            dot.bounds = CGRect(x: 0, y: 0, width: 6, height: 6)
            layer?.addSublayer(dot)
            dotLayers.append(dot)
            if !reduceMotion {
                let breath = CABasicAnimation(keyPath: "opacity")
                breath.fromValue = 0.3
                breath.toValue = 1.0
                breath.duration = 1.2
                breath.autoreverses = true
                breath.repeatCount = .infinity
                dot.add(breath, forKey: "opacity")
            }
        }
        _ = stack
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func layout() {
        super.layout()
        let total = CGFloat(dotLayers.count) * 12
        var x = (bounds.width - total) / 2
        for dot in dotLayers {
            dot.position = CGPoint(x: x + 3, y: bounds.midY)
            x += 12
        }
    }
}

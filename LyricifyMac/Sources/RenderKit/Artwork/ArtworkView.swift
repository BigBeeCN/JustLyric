import AppKit

/// 封面视图（S4 §4.1 ArtworkView；进入动画 S4 §4.6：缩放+透明度 spring）。
public final class ArtworkView: NSView {
    private let imageLayer = CALayer()

    /// 创建封面视图。
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(imageLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func layout() {
        super.layout()
        imageLayer.frame = bounds
    }

    /// 设置封面。
    /// - Parameter image: 封面图。
    public func setImage(_ image: NSImage?) {
        imageLayer.contents = image
    }

    /// 进入动画（S4 §4.6：缩放+透明度；ReduceMotion 仅淡入）。
    /// - Parameter reduceMotion: 减弱动态效果。
    public func enter(reduceMotion: Bool = false) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.35
        imageLayer.add(fade, forKey: "opacity")

        guard !reduceMotion else { return }
        let scale = CASpringAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.9
        scale.toValue = 1.0
        scale.mass = 1
        scale.stiffness = pow(2 * Double.pi / 0.35, 2) // spring(0.35) 近似
        scale.damping = 2 * 0.7 * sqrt(scale.stiffness)
        imageLayer.add(scale, forKey: "transform.scale")
    }
}

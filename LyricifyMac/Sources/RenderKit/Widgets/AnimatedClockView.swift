import AppKit
import LyricsCore

/// 数字翻牌时钟（S4 §1 AnimatedClockView；M5 波次 2）。
///
/// - 时钟注入（D30 #5：禁直读系统时钟）；
/// - 翻牌动画属 CA 层 UI 动画域（D30 #6）；ReduceMotion 直切无翻牌。
public final class AnimatedClockView: NSView {
    private let clock: TimelineProviding
    private let reduceMotion: Bool
    private var digitLayers: [CATextLayer] = []
    private var lastText = ""
    /// 当前显示文本（测试断言）。
    public private(set) var currentText = ""

    /// 创建翻牌时钟。
    /// - Parameters:
    ///   - clock: 时间轴。
    ///   - font: 数字字体（默认快照基准）。
    ///   - reduceMotion: 减弱动态效果。
    public init(
        clock: TimelineProviding,
        font: NSFont = SnapshotBaseline.font,
        reduceMotion: Bool = false
    ) {
        self.clock = clock
        self.reduceMotion = reduceMotion
        super.init(frame: .zero)
        wantsLayer = true
        for _ in 0 ..< 5 { // mm:ss = 5 字位
            let digit = CATextLayer()
            digit.font = font
            digit.fontSize = font.pointSize
            digit.alignmentMode = .center
            layer?.addSublayer(digit)
            digitLayers.append(digit)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func layout() {
        super.layout()
        let slot = bounds.width / CGFloat(digitLayers.count)
        for (index, digit) in digitLayers.enumerated() {
            digit.frame = CGRect(
                x: CGFloat(index) * slot,
                y: 0,
                width: slot,
                height: bounds.height
            )
        }
    }

    /// 逐帧更新（mm:ss；变化字位翻牌）。
    /// - Parameter now: 外部时钟读数（D30 #5）。
    public func tick(now: TimeInterval) {
        let totalSeconds = max(0, clock.elapsed(now: now) / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let text = String(format: "%02d:%02d", minutes, seconds)
        guard text != lastText else { return }
        let chars = Array(text)
        for (index, digitLayer) in digitLayers.enumerated() where index < chars.count {
            let next = String(chars[index])
            let previous = index < lastText.count ? String(Array(lastText)[index]) : ""
            guard next != previous else { continue }
            digitLayer.string = next
            guard !reduceMotion else { continue }
            let flip = CATransition()
            flip.type = .push
            flip.subtype = .fromTop // 翻牌（CA 层 UI 动画域，D30 #6）
            flip.duration = 0.25
            digitLayer.add(flip, forKey: "flip")
        }
        lastText = text
        currentText = text
    }
}

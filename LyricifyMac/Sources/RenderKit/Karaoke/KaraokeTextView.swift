import AppKit
import CoreText
import LyricsCore

/// 逐字填充文本视图（S4 §2 核心组件；S7 D30 #1/#5/#6）。
///
/// - 两文本层：`baseLayer`（未唱色 × `unplayedOpacity`）+ `fillLayer`（已唱色），
///   同字体同位置；`fillLayer` 以 `CALayer.mask` 按填充边界裁剪（S4 §2.2.3）；
/// - **D30 #1**：词宽按最终布局字形宽一次性缓存（``updateLine(_:)`` 时测量），
///   逐帧 `tick(now:)` 只更新 mask，禁止重排文本；
/// - **D30 #5**：时间只认注入的 `TimelineProviding`，`now` 由调用方（显示链路）供给，
///   组件禁止直读系统时钟；
/// - **D30 #6**：填充域为逐帧线性插值（无 CA 曲线）；滚动/浮起等 spring 动画在
///   其他组件（CA 层）实现，两域时间基准不得混用。
public final class KaraokeTextView: NSView {
    /// 快照/测量基准字体（S7 D30 #4：系统字体 17pt 固定）。
    public static let snapshotFont = NSFont.systemFont(ofSize: 17)

    private let baseLayer = CATextLayer()
    private let fillLayer = CATextLayer()
    private let maskLayer = CAGradientLayer()
    private let clock: TimelineProviding
    private var style: KaraokeStyle
    private var line: LyricsLine
    private var layouts: [FillGeometry.SyllableLayout] = []

    /// 文本重排计数（D30 #1 回归断言：逐帧不得增长）。
    public private(set) var relayoutCount = 0
    /// 最近一次 mask 宽度（pt）。
    public private(set) var lastMaskWidth: CGFloat = 0
    /// 文本实宽（一次性缓存；填充扫描基准——D48：视口宽致边缘冲出文本区）。
    private var textWidth: Double = 0
    /// 是否换行（长句换行快照用）。
    public var wrapsText = false {
        didSet {
            baseLayer.isWrapped = wrapsText
            fillLayer.isWrapped = wrapsText
        }
    }

    /// 创建视图。
    /// - Parameters:
    ///   - line: 歌词行。
    ///   - clock: 时间轴（D30 #5）。
    ///   - style: 样式。
    ///   - font: 字体（默认 17pt 系统字体，D30 #4）。
    public init(
        line: LyricsLine,
        clock: TimelineProviding,
        style: KaraokeStyle = KaraokeStyle(),
        font: NSFont = KaraokeTextView.snapshotFont
    ) {
        self.line = line
        self.clock = clock
        self.style = style
        super.init(frame: .zero)
        wantsLayer = true
        baseLayer.font = font
        fillLayer.font = font
        baseLayer.fontSize = font.pointSize
        fillLayer.fontSize = font.pointSize
        maskLayer.startPoint = CGPoint(x: 0, y: 0.5)
        maskLayer.endPoint = CGPoint(x: 1, y: 0.5)
        fillLayer.mask = maskLayer
        layer?.addSublayer(baseLayer)
        layer?.addSublayer(fillLayer)
        updateLine(line)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func layout() {
        super.layout()
        baseLayer.frame = bounds
        fillLayer.frame = bounds
    }

    // MARK: - 内容

    /// 长行自适应字号（M3 AdaptiveText 融合；避免换行破坏 mask 几何）。
    public var fitsLineToWidth = true

    /// 更新歌词行（唯一重排入口：测量词宽一次缓存，D30 #1）。
    /// - Parameter line: 歌词行。
    public func updateLine(_ line: LyricsLine) {
        self.line = line
        relayoutCount += 1

        // 长行自适应（D44：单行完整显示，替代换行）。
        if fitsLineToWidth, bounds.width > 0 {
            let fitted = AdaptiveTextFitting.fittedFontSize(
                text: line.text,
                baseFont: (baseLayer.font as? NSFont) ?? KaraokeTextView.snapshotFont,
                width: bounds.width - 2,
                minScale: 0.5
            )
            let font = NSFont.systemFont(ofSize: fitted)
            baseLayer.font = font
            fillLayer.font = font
            baseLayer.fontSize = fitted
            fillLayer.fontSize = fitted
        }

        let attributed = NSAttributedString(
            string: line.text,
            attributes: [
                .font: (baseLayer.font as? NSFont) ?? KaraokeTextView.snapshotFont,
                .foregroundColor: NSColor.labelColor,
            ]
        )
        baseLayer.string = attributed
        fillLayer.string = NSAttributedString(
            string: line.text,
            attributes: [
                .font: (baseLayer.font as? NSFont) ?? KaraokeTextView.snapshotFont,
                .foregroundColor: style.playedColor.flatMap { NSColor(cgColor: $0) } ?? NSColor.labelColor,
            ]
        )

        // 词宽一次性缓存（最终布局字形宽）。
        let font = (baseLayer.font as? NSFont) ?? KaraokeTextView.snapshotFont
        textWidth = measureWidth(line.text, font: font)
        layouts = (line.syllables ?? []).map { syllable in
            FillGeometry.SyllableLayout(
                startMs: syllable.startMs,
                durationMs: syllable.durationMs,
                width: measureWidth(syllable.text, font: font)
            )
        }
        baseLayer.opacity = Float(style.unplayedOpacity)
    }

    // MARK: - 逐帧

    /// 逐帧推进（填充域逐帧插值，D30 #6；只动 mask，D30 #1）。
    ///
    /// > Important: `now` 由显示链路外部供给（D30 #5：组件禁止直读系统时钟）。
    /// - Parameter now: 外部时钟读数（秒）。
    public func tick(now: TimeInterval) {
        let mediaMs = Double(clock.elapsed(now: now))
        // D48：扫描基准 = 文本实宽（兜底视口宽），填充边缘不冲出文本区。
        let lineWidth = textWidth > 0 ? textWidth : Double(bounds.width)
        let boundary = FillGeometry.fillBoundary(
            layouts: layouts,
            lineStartMs: line.startMs,
            lineEndMs: line.endMs,
            nowMs: mediaMs,
            lineWidth: lineWidth,
            linear: style.disableCJKKaraoke || layouts.isEmpty
        )
        applyMask(boundary: CGFloat(boundary), lineWidth: CGFloat(max(lineWidth, 1)))
    }

    // MARK: - 私有

    /// 更新 mask（唯一逐帧写入点）。
    private func applyMask(boundary: CGFloat, lineWidth: CGFloat) {
        let clamped = min(max(0, boundary), lineWidth)
        lastMaskWidth = clamped
        maskLayer.frame = CGRect(x: 0, y: 0, width: lineWidth, height: bounds.height)

        // fillSoftness：边界前 softness 区间渐隐（0–2pt，S4 §2.2.6）。
        // D44：locations 必须 0≤edge≤location≤1 单调——非单调（负 edge）致渐变
        // 未定义渲染（实测症状：仅行中段可见、前端截断）。
        let softness = min(2, max(0, CGFloat(style.fillSoftness)))
        let rawLocation = lineWidth > 0 ? clamped / lineWidth : 0
        let location = min(1, max(0, rawLocation))
        let edge = min(location, max(0, lineWidth > 0 ? (clamped - softness) / lineWidth : 0))
        maskLayer.colors = [NSColor.white.cgColor, NSColor.white.cgColor, NSColor.clear.cgColor]
        maskLayer.locations = [0, NSNumber(value: Double(edge)), NSNumber(value: Double(location))]
    }

    /// 字形宽测量（一次缓存用）。
    private func measureWidth(_ text: String, font: NSFont) -> Double {
        Double((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

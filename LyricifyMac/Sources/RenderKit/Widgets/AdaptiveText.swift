import AppKit

/// 自适应文本（S4 §1 AdaptiveText：自适应字号/拉伸）。
public enum AdaptiveTextFitting {
    /// 拟合字号（缩小至可容纳；下限为基准 × minScale）。
    /// - Parameters:
    ///   - text: 文本。
    ///   - baseFont: 基准字体。
    ///   - width: 可用宽度 pt。
    ///   - minScale: 最小缩放比。
    /// - Returns: 拟合字号。
    public static func fittedFontSize(
        text: String,
        baseFont: NSFont,
        width: CGFloat,
        minScale: CGFloat = 0.5
    ) -> CGFloat {
        var size = baseFont.pointSize
        let floorSize = baseFont.pointSize * minScale
        while size > floorSize {
            let font = NSFont.systemFont(ofSize: size)
            let measured = (text as NSString).size(withAttributes: [.font: font]).width
            if measured <= width {
                return size
            }
            size -= 1
        }
        return floorSize
    }
}

/// 自适应文本视图（字号拟合 + 拉伸）。
public final class AdaptiveTextView: NSView {
    private let textLayer = CATextLayer()

    /// 创建视图。
    /// - Parameter font: 基准字体（默认快照基准 17pt，D30 #4）。
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

    /// 铺设文本（自适应字号）。
    /// - Parameter text: 文本。
    public func setText(_ text: String) {
        let fitted = AdaptiveTextFitting.fittedFontSize(
            text: text,
            baseFont: SnapshotBaseline.font,
            width: max(1, bounds.width)
        )
        textLayer.fontSize = fitted
        textLayer.string = text
        textLayer.frame = bounds
    }
}

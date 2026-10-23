import AppKit

/// 桌面歌词样式（S4 §5 三套样式 + 描边/阴影；S7 D33 #4 默认值）。
public struct DesktopLyricsStyle {
    /// 样式预设（S4 §5：duoLineStyle/singleLineStyle/karaokeStyle）。
    public enum Preset: Sendable {
        /// 单行（24pt Bold）。
        case singleLine
        /// 双行（22+16pt，副行 70%）。
        case duoLine
        /// 卡拉OK（24pt Bold + D30#3）。
        case karaoke
    }

    /// 主字号 pt。
    public var fontSize: Double
    /// 副字号 pt（双行）。
    public var secondaryFontSize: Double
    /// 粗体。
    public var bold: Bool
    /// 卡拉OK 样式（D30 #3 默认直通）。
    public var karaokeStyle: KaraokeStyle

    /// 阴影 6 参数（S4 §5；D33 #4：black/0.5/8pt/2pt/270°）。
    /// 阴影色（黑）。
    public var shadowColor: CGColor = NSColor.black.cgColor
    /// 阴影透明度（0.5）。
    public var shadowOpacity: Double = 0.5
    /// 阴影半径 pt（8）。
    public var shadowRadius: Double = 8
    /// 阴影深度 pt（2）。
    public var shadowDepth: Double = 2
    /// 阴影方向度（270°）。
    public var shadowDirectionDegrees: Double = 270
    /// 阴影开关。
    public var enableShadowEffect = true

    /// 描边（S4 §5 双色；D33 #4：默认关）。
    /// 描边开关（默认关）。
    public var borderEnabled = false
    /// 描边厚度。
    public var borderThickness: Double = 0
    /// 第一描边色。
    public var firstBorder: CGColor?
    /// 第一填充色。
    public var firstFill: CGColor?
    /// 第二描边色。
    public var secondBorder: CGColor?
    /// 第二填充色。
    public var secondFill: CGColor?

    /// 创建样式。
    /// - Parameters:
    ///   - fontSize: 主字号。
    ///   - secondaryFontSize: 副字号。
    ///   - bold: 粗体。
    ///   - karaokeStyle: 卡拉OK 样式。
    public init(
        fontSize: Double,
        secondaryFontSize: Double,
        bold: Bool,
        karaokeStyle: KaraokeStyle = KaraokeStyle()
    ) {
        self.fontSize = fontSize
        self.secondaryFontSize = secondaryFontSize
        self.bold = bold
        self.karaokeStyle = karaokeStyle
    }

    /// 预设（D33 #4 默认值）。
    /// - Parameter preset: 预设。
    /// - Returns: 样式。
    public static func preset(_ preset: Preset) -> DesktopLyricsStyle {
        switch preset {
        case .singleLine:
            DesktopLyricsStyle(fontSize: 24, secondaryFontSize: 0, bold: true)
        case .duoLine:
            // 副行 70%：22 × 0.7 ≈ 16pt（D33 #4）。
            DesktopLyricsStyle(fontSize: 22, secondaryFontSize: 16, bold: false)
        case .karaoke:
            DesktopLyricsStyle(fontSize: 24, secondaryFontSize: 0, bold: true, karaokeStyle: KaraokeStyle())
        }
    }
}

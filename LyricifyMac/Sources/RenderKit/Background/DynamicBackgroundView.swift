import AppKit

/// 动态背景配置（S4 §4；S7 D33 #2/#3）。
public struct DynamicBackgroundConfig: Sendable {
    /// 背景类型（S4 §4.5）。
    public enum BackgroundType: String, Sendable {
        /// 纯色。
        case solid
        /// 渐变。
        case gradient
        /// 模糊。
        case blur
        /// 动态。
        case dynamic
    }

    /// 背景类型。
    public var backgroundType: BackgroundType = .gradient
    /// 目标帧率（D33 #3：默认 24，上限 30）。
    public var frameRate: Double = 24
    /// 渲染倍率（D33 #3：默认 1.0）。
    public var renderScale: Double = 1.0
    /// 效率模式（D33 #3：0.5 倍率 / 15fps）。
    public var efficiencyMode = false
    /// 降色带抖动开关（D33 #2：`background_isolation_reduce_color_banding`）。
    public var reduceColorBanding = true
    /// 模糊等级（S4 §4.5）。
    public var blurLevel: Double = 0.5
    /// 背景透明度（S4 §4.5）。
    public var backgroundOpacity: Double = 1.0

    /// 创建配置。
    public init() {}

    /// 生效帧率（D33 #3）。
    public var effectiveFrameRate: Double {
        efficiencyMode ? 15 : min(30, max(1, frameRate))
    }

    /// 生效渲染倍率（D33 #3）。
    public var effectiveRenderScale: Double {
        efficiencyMode ? 0.5 : renderScale
    }
}

/// 动态背景视图（S4 §4：主色→辅色对角渐变 + 模糊层 + 抖动；背景动画 ≤30fps）。
///
/// > Important: 文本动画不受背景帧率影响（D33 #3 域分离）。
public final class DynamicBackgroundView: NSView {
    private let gradientLayer = CAGradientLayer()
    private var timer: DispatchSourceTimer?
    private var config = DynamicBackgroundConfig()

    /// 当前抖动振幅 LSB（D33 #2：±1；渲染通道逐像素应用）。
    public private(set) var appliedDitherAmplitude: Double = 0

    /// 创建背景视图。
    /// - Parameter palette: 调色板。
    public init(palette: ArtworkPalette) {
        super.init(frame: .zero)
        wantsLayer = true
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1) // 对角渐变（S4 §4.2）
        apply(palette: palette)
        layer?.addSublayer(gradientLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        timer?.cancel()
    }

    /// 应用调色板（主色→辅色）。
    /// - Parameter palette: 调色板。
    public func apply(palette: ArtworkPalette) {
        gradientLayer.colors = [cgColor(palette.primary), cgColor(palette.secondary)]
        // D33 #2：reduceColorBanding 开 → 抖动 ±1 LSB（≈0.4%）；关 → 0。
        appliedDitherAmplitude = config.reduceColorBanding ? BlueNoiseDither.amplitude : 0
        gradientLayer.setNeedsDisplay()
    }

    /// 启动背景动画（生效帧率受 D33 #3 约束）。
    /// - Parameters:
    ///   - config: 配置。
    ///   - reduceMotion: 减弱动态效果（背景静态）。
    public func start(config: DynamicBackgroundConfig, reduceMotion: Bool = false) {
        self.config = config
        timer?.cancel()
        guard !reduceMotion, config.backgroundType == .dynamic else { return }
        let source = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        source.schedule(
            deadline: .now(),
            repeating: 1.0 / config.effectiveFrameRate
        )
        source.setEventHandler { [weak self] in
            self?.pulse()
        }
        source.resume()
        timer = source
    }

    private func pulse() {
        DispatchQueue.main.async { [weak self] in
            self?.gradientLayer.opacity = self?.gradientLayer.opacity == 1 ? 0.92 : 1
        }
    }

    private func cgColor(_ color: PixelRGB) -> CGColor {
        NSColor(
            srgbRed: CGFloat(color.r / 255),
            green: CGFloat(color.g / 255),
            blue: CGFloat(color.b / 255),
            alpha: config.backgroundOpacity
        ).cgColor
    }
}

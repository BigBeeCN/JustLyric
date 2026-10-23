import AppKit

/// 逐字填充样式（S4 §2.3 设置直通；S7 D30 #3 MVP 默认值）。
public struct KaraokeStyle {
    /// 浮起开关（`karaoke_style_float`）。
    public var floatEnabled: Bool
    /// 浮起高度 pt（D30 #3：默认 2）。
    public var floatHeight: Double
    /// 进度条宽 pt（D30 #3：默认 8）。
    public var progressWidth: Double
    /// 词辉光开关（`karaoke_style_word_shine`）。
    public var wordShine: Bool
    /// 动画开关（`karaoke_style_enable_animation`）。
    public var animationEnabled: Bool
    /// 中文滚动缓动（`karaoke_chinese_easing`）。
    public var chineseRollingEasing: Bool
    /// 禁用 CJK 逐字 karaoke（`disable_cjk_karaoke` → 整行线性，S4 §2.2.5）。
    public var disableCJKKaraoke: Bool
    /// 未唱行透明度（D30 #3：默认 0.55）。
    public var unplayedOpacity: Double
    /// 填充边缘柔化 pt（0–2；D30 #3：默认 1）。
    public var fillSoftness: Double
    /// 已唱颜色。
    public var playedColor: CGColor?
    /// 未唱颜色。
    public var baseColor: CGColor?
    /// 次级颜色。
    public var secondaryColor: CGColor?

    /// 创建样式（MVP 默认值见 S7 D30 #3）。
    /// - Parameters:
    ///   - floatEnabled: 浮起开关。
    ///   - floatHeight: 浮起高度 pt。
    ///   - progressWidth: 进度条宽 pt。
    ///   - wordShine: 词辉光开关。
    ///   - animationEnabled: 动画开关。
    ///   - chineseRollingEasing: 中文滚动缓动。
    ///   - disableCJKKaraoke: 禁用 CJK 逐字。
    ///   - unplayedOpacity: 未唱行透明度。
    ///   - fillSoftness: 填充边缘柔化 pt。
    ///   - playedColor: 已唱颜色。
    ///   - baseColor: 未唱颜色。
    ///   - secondaryColor: 次级颜色。
    public init(
        floatEnabled: Bool = false,
        floatHeight: Double = 2,
        progressWidth: Double = 8,
        wordShine: Bool = false,
        animationEnabled: Bool = true,
        chineseRollingEasing: Bool = false,
        disableCJKKaraoke: Bool = false,
        unplayedOpacity: Double = 0.55,
        fillSoftness: Double = 1,
        playedColor: CGColor? = nil,
        baseColor: CGColor? = nil,
        secondaryColor: CGColor? = nil
    ) {
        self.floatEnabled = floatEnabled
        self.floatHeight = floatHeight
        self.progressWidth = progressWidth
        self.wordShine = wordShine
        self.animationEnabled = animationEnabled
        self.chineseRollingEasing = chineseRollingEasing
        self.disableCJKKaraoke = disableCJKKaraoke
        self.unplayedOpacity = unplayedOpacity
        self.fillSoftness = fillSoftness
        self.playedColor = playedColor
        self.baseColor = baseColor
        self.secondaryColor = secondaryColor
    }
}

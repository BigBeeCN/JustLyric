import Foundation

// 设置模型（S5 §1.1 MVP 键；S7 D35 ⭐：初值=组件已定默认，缺键回退组件默认禁崩）。
//
// 解码策略：全部 `decodeIfPresent` + 默认值（坏 JSON/缺键不崩）。

// MARK: - general

public struct GeneralSettings: Codable, Equatable, Sendable {
    /// 语言（"system"=跟随系统）。
    public var language: String
    /// 浅色主题（`is_light_theme`）。
    public var isLightTheme: Bool
    /// 开机自启。
    public var launchAtLogin: Bool
    /// 单实例。
    public var singleInstance: Bool

    public init(
        language: String = "system",
        isLightTheme: Bool = false,
        launchAtLogin: Bool = false,
        singleInstance: Bool = true
    ) {
        self.language = language
        self.isLightTheme = isLightTheme
        self.launchAtLogin = launchAtLogin
        self.singleInstance = singleInstance
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? "system"
        isLightTheme = try c.decodeIfPresent(Bool.self, forKey: .isLightTheme) ?? false
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        singleInstance = try c.decodeIfPresent(Bool.self, forKey: .singleInstance) ?? true
    }
}

// MARK: - lyrics

public struct LyricsSettings: Codable, Equatable, Sendable {
    /// 罗马音选项。
    public enum RomajiOption: String, Codable, Sendable {
        /// 关。
        case off
        /// 罗马字。
        case romaji
        /// 平假名。
        case hiragana
    }

    /// 显示翻译（`translation`）。
    public var translation: Bool
    /// 罗马音选项。
    public var romajiOption: RomajiOption
    /// 简体优先。
    public var preferSimplifiedChinese: Bool
    /// 中文长句切分开关。
    public var enableChineseLongSentenceSegmentation: Bool
    /// 标题行数（`auto` = nil，D17 可覆盖 auto）。
    public var titleLines: Int?
    /// 显示显式标记（`show_explicit`）。
    public var showExplicit: Bool

    public init(
        translation: Bool = false,
        romajiOption: RomajiOption = .off,
        preferSimplifiedChinese: Bool = true,
        enableChineseLongSentenceSegmentation: Bool = true,
        titleLines: Int? = nil,
        showExplicit: Bool = true
    ) {
        self.translation = translation
        self.romajiOption = romajiOption
        self.preferSimplifiedChinese = preferSimplifiedChinese
        self.enableChineseLongSentenceSegmentation = enableChineseLongSentenceSegmentation
        self.titleLines = titleLines
        self.showExplicit = showExplicit
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        translation = try c.decodeIfPresent(Bool.self, forKey: .translation) ?? false
        romajiOption = try c.decodeIfPresent(RomajiOption.self, forKey: .romajiOption) ?? .off
        preferSimplifiedChinese = try c.decodeIfPresent(Bool.self, forKey: .preferSimplifiedChinese) ?? true
        enableChineseLongSentenceSegmentation = try c.decodeIfPresent(
            Bool.self, forKey: .enableChineseLongSentenceSegmentation
        ) ?? true
        titleLines = try c.decodeIfPresent(Int.self, forKey: .titleLines)
        showExplicit = try c.decodeIfPresent(Bool.self, forKey: .showExplicit) ?? true
    }
}

// MARK: - karaoke（D30 #3 默认直通）

public struct KaraokeSettings: Codable, Equatable, Sendable {
    /// karaoke 开关。
    public var isKaraoke: Bool
    /// 禁用 CJK 逐字。
    public var disableCJKKaraoke: Bool
    /// 浮起开关。
    public var karaokeStyleFloat: Bool
    /// 浮起高度（D30 #3：2pt）。
    public var karaokeStyleFloatHeight: Double
    /// 进度宽（D30 #3：8pt）。
    public var karaokeStyleProgressWidth: Double
    /// 词辉光。
    public var karaokeStyleWordShine: Bool
    /// 中文滚动缓动。
    public var karaokeChineseEasing: Bool
    /// 未唱透明度（D30 #3：0.55）。
    public var unplayingOpacityOverride: Double

    public init(
        isKaraoke: Bool = true,
        disableCJKKaraoke: Bool = false,
        karaokeStyleFloat: Bool = false,
        karaokeStyleFloatHeight: Double = 2,
        karaokeStyleProgressWidth: Double = 8,
        karaokeStyleWordShine: Bool = false,
        karaokeChineseEasing: Bool = false,
        unplayingOpacityOverride: Double = 0.55
    ) {
        self.isKaraoke = isKaraoke
        self.disableCJKKaraoke = disableCJKKaraoke
        self.karaokeStyleFloat = karaokeStyleFloat
        self.karaokeStyleFloatHeight = karaokeStyleFloatHeight
        self.karaokeStyleProgressWidth = karaokeStyleProgressWidth
        self.karaokeStyleWordShine = karaokeStyleWordShine
        self.karaokeChineseEasing = karaokeChineseEasing
        self.unplayingOpacityOverride = unplayingOpacityOverride
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isKaraoke = try c.decodeIfPresent(Bool.self, forKey: .isKaraoke) ?? true
        disableCJKKaraoke = try c.decodeIfPresent(Bool.self, forKey: .disableCJKKaraoke) ?? false
        karaokeStyleFloat = try c.decodeIfPresent(Bool.self, forKey: .karaokeStyleFloat) ?? false
        karaokeStyleFloatHeight = try c.decodeIfPresent(Double.self, forKey: .karaokeStyleFloatHeight) ?? 2
        karaokeStyleProgressWidth = try c.decodeIfPresent(Double.self, forKey: .karaokeStyleProgressWidth) ?? 8
        karaokeStyleWordShine = try c.decodeIfPresent(Bool.self, forKey: .karaokeStyleWordShine) ?? false
        karaokeChineseEasing = try c.decodeIfPresent(Bool.self, forKey: .karaokeChineseEasing) ?? false
        unplayingOpacityOverride = try c.decodeIfPresent(Double.self, forKey: .unplayingOpacityOverride) ?? 0.55
    }
}

// MARK: - desktop_lyrics（D33 #4 阴影默认直通）

public struct DesktopLyricsSettings: Codable, Equatable, Sendable {
    /// 窗口矩形（x/y/w/h）。
    public struct WindowRect: Codable, Equatable, Sendable {
        /// x。
        public var x: Double
        /// y。
        public var y: Double
        /// 宽。
        public var width: Double
        /// 高。
        public var height: Double

        public init(x: Double = 100, y: Double = 100, width: Double = 800, height: Double = 200) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 100
            y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 100
            width = try c.decodeIfPresent(Double.self, forKey: .width) ?? 800
            height = try c.decodeIfPresent(Double.self, forKey: .height) ?? 200
        }
    }

    /// 窗口矩形。
    public var window: WindowRect
    /// 锁定。
    public var isLocked: Bool
    /// 强制置顶。
    public var forceTopmost: Bool
    /// 自动隐藏。
    public var autoHide: Bool
    /// 进入隐藏（`enter_hide`）。
    public var enterHide: Bool
    /// 全屏时隐藏。
    public var fullscreenHide: Bool
    /// 描边厚度（D33 #4：0=关）。
    public var borderThickness: Double
    /// 字体族（空=系统字体）。
    public var fontFamily: String
    /// 字号缩放。
    public var fontSizeScale: Double
    /// 双行模式。
    public var duoLine: Bool
    /// 对齐（left/center/right）。
    public var lyricsAlign: String
    /// 阴影开关。
    public var enableShadowEffect: Bool
    /// 阴影色（D33 #4：black）。
    public var shadowColor: String
    /// 阴影透明度（0.5）。
    public var shadowOpacity: Double
    /// 阴影半径（8pt）。
    public var shadowRadius: Double
    /// 阴影深度（2pt）。
    public var shadowDepth: Double
    /// 阴影方向（270°）。
    public var shadowDirection: Double

    public init() {
        window = WindowRect()
        isLocked = false
        forceTopmost = true
        autoHide = true
        enterHide = false
        fullscreenHide = true
        borderThickness = 0
        fontFamily = ""
        fontSizeScale = 1.0
        duoLine = false
        lyricsAlign = "center"
        enableShadowEffect = true
        shadowColor = "black"
        shadowOpacity = 0.5
        shadowRadius = 8
        shadowDepth = 2
        shadowDirection = 270
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        window = try c.decodeIfPresent(WindowRect.self, forKey: .window) ?? WindowRect()
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        forceTopmost = try c.decodeIfPresent(Bool.self, forKey: .forceTopmost) ?? true
        autoHide = try c.decodeIfPresent(Bool.self, forKey: .autoHide) ?? true
        enterHide = try c.decodeIfPresent(Bool.self, forKey: .enterHide) ?? false
        fullscreenHide = try c.decodeIfPresent(Bool.self, forKey: .fullscreenHide) ?? true
        borderThickness = try c.decodeIfPresent(Double.self, forKey: .borderThickness) ?? 0
        fontFamily = try c.decodeIfPresent(String.self, forKey: .fontFamily) ?? ""
        fontSizeScale = try c.decodeIfPresent(Double.self, forKey: .fontSizeScale) ?? 1.0
        duoLine = try c.decodeIfPresent(Bool.self, forKey: .duoLine) ?? false
        lyricsAlign = try c.decodeIfPresent(String.self, forKey: .lyricsAlign) ?? "center"
        enableShadowEffect = try c.decodeIfPresent(Bool.self, forKey: .enableShadowEffect) ?? true
        shadowColor = try c.decodeIfPresent(String.self, forKey: .shadowColor) ?? "black"
        shadowOpacity = try c.decodeIfPresent(Double.self, forKey: .shadowOpacity) ?? 0.5
        shadowRadius = try c.decodeIfPresent(Double.self, forKey: .shadowRadius) ?? 8
        shadowDepth = try c.decodeIfPresent(Double.self, forKey: .shadowDepth) ?? 2
        shadowDirection = try c.decodeIfPresent(Double.self, forKey: .shadowDirection) ?? 270
    }
}

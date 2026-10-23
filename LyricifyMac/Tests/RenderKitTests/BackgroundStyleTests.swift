import XCTest
@testable import RenderKit

/// 抖动/背景/样式默认测试（S4 §4/§5；S7 D33 #2/#3/#4）。
final class BackgroundStyleTests: XCTestCase {
    /// D33 #2：64×64 平铺、±1 LSB、确定性、关闭开关。
    func testBlueNoiseDither() {
        let tile = BlueNoiseDither.tile()
        XCTAssertEqual(tile.count, 64 * 64)
        XCTAssertEqual(tile, BlueNoiseDither.tile(), "确定性平铺")

        for _ in 0 ..< 50 {
            let x = Int.random(in: 0 ..< 64)
            let y = Int.random(in: 0 ..< 64)
            let offset = BlueNoiseDither.offset(x: x, y: y)
            XCTAssertLessThanOrEqual(abs(offset), BlueNoiseDither.amplitude + 0.0001)
        }
        XCTAssertEqual(
            BlueNoiseDither.offset(x: 3, y: 7, amplitude: 0), 0,
            "reduceColorBanding=false → 无抖动"
        )
    }

    /// D33 #3：背景帧率默认 24（≤30）；efficiency 0.5/15fps。
    func testBackgroundFrameConfig() {
        let config = DynamicBackgroundConfig()
        XCTAssertEqual(config.frameRate, 24, accuracy: 0.001)
        XCTAssertEqual(config.effectiveFrameRate, 24, accuracy: 0.001)
        XCTAssertEqual(config.effectiveRenderScale, 1.0, accuracy: 0.001)

        var fast = DynamicBackgroundConfig()
        fast.frameRate = 60
        XCTAssertEqual(fast.effectiveFrameRate, 30, accuracy: 0.001, "上限 30fps")

        var efficient = DynamicBackgroundConfig()
        efficient.efficiencyMode = true
        XCTAssertEqual(efficient.effectiveFrameRate, 15, accuracy: 0.001)
        XCTAssertEqual(efficient.effectiveRenderScale, 0.5, accuracy: 0.001)
    }

    /// D33 #2 开关落到背景视图。
    func testDitherToggleOnBackground() {
        let palette = ArtworkPalette(
            primary: PixelRGB(r: 10, g: 10, b: 10),
            secondary: PixelRGB(r: 200, g: 200, b: 200)
        )
        let background = DynamicBackgroundView(palette: palette)
        XCTAssertEqual(background.appliedDitherAmplitude, BlueNoiseDither.amplitude)

        var config = DynamicBackgroundConfig()
        config.reduceColorBanding = false
        background.start(config: config, reduceMotion: true)
        background.apply(palette: palette)
        XCTAssertEqual(background.appliedDitherAmplitude, 0, "关闭抖动")
    }

    /// D33 #4：三套样式默认。
    func testStylePresets() {
        let single = DesktopLyricsStyle.preset(.singleLine)
        XCTAssertEqual(single.fontSize, 24, accuracy: 0.001)
        XCTAssertTrue(single.bold)

        let duo = DesktopLyricsStyle.preset(.duoLine)
        XCTAssertEqual(duo.fontSize, 22, accuracy: 0.001)
        XCTAssertEqual(duo.secondaryFontSize, 16, accuracy: 0.001)

        let karaoke = DesktopLyricsStyle.preset(.karaoke)
        XCTAssertEqual(karaoke.fontSize, 24, accuracy: 0.001)
        XCTAssertEqual(karaoke.karaokeStyle.floatHeight, 2, accuracy: 0.001, "D30#3 直通")

        // 阴影 6 参数（D33 #4：black/0.5/8pt/2pt/270°）。
        XCTAssertEqual(single.shadowOpacity, 0.5, accuracy: 0.001)
        XCTAssertEqual(single.shadowRadius, 8, accuracy: 0.001)
        XCTAssertEqual(single.shadowDepth, 2, accuracy: 0.001)
        XCTAssertEqual(single.shadowDirectionDegrees, 270, accuracy: 0.001)
        XCTAssertTrue(single.enableShadowEffect)
        // 描边默认关。
        XCTAssertFalse(single.borderEnabled)
        XCTAssertEqual(single.borderThickness, 0)
    }

    /// 封面进入动画（ReduceMotion 仅淡入）。
    func testArtworkEnter() {
        let view = ArtworkView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        view.enter(reduceMotion: true)
        let keys = view.layer?.sublayers?.first?.animationKeys() ?? []
        XCTAssertTrue(keys.contains("opacity"))
        XCTAssertFalse(keys.contains("transform.scale"), "ReduceMotion 无缩放")

        let animated = ArtworkView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        animated.enter()
        let animatedKeys = animated.layer?.sublayers?.first?.animationKeys() ?? []
        XCTAssertTrue(animatedKeys.contains("transform.scale"))
    }
}

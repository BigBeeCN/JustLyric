import XCTest
@testable import RenderKit

/// 词辉光测试（S4 §3；S7 D30 #2）。
final class WordShineEffectTests: XCTestCase {
    /// D30 #2：预设系数 0.6/1.0/1.4、模糊 2/4/8pt（17pt 基准）。
    func testPresetCoefficients() {
        XCTAssertEqual(WordShineEffect.Preset.soft.brightnessFactor, 0.6, accuracy: 0.001)
        XCTAssertEqual(WordShineEffect.Preset.normal.brightnessFactor, 1.0, accuracy: 0.001)
        XCTAssertEqual(WordShineEffect.Preset.strong.brightnessFactor, 1.4, accuracy: 0.001)
        XCTAssertEqual(WordShineEffect.blurPt(preset: .soft, fontPointSize: 17), 2, accuracy: 0.001)
        XCTAssertEqual(WordShineEffect.blurPt(preset: .normal, fontPointSize: 17), 4, accuracy: 0.001)
        XCTAssertEqual(WordShineEffect.blurPt(preset: .strong, fontPointSize: 17), 8, accuracy: 0.001)
    }

    /// D30 #2：模糊随字号缩放。
    func testBlurScalesWithFontSize() {
        XCTAssertEqual(WordShineEffect.blurPt(preset: .strong, fontPointSize: 34), 16, accuracy: 0.001)
    }

    /// D30 #2：进 120ms/出 240ms 线性包络，三档时间一致。
    func testEnvelope() {
        for preset in WordShineEffect.Preset.allCases {
            let peak = preset.brightnessFactor
            // 进入：60ms = 半亮。
            XCTAssertEqual(
                WordShineEffect.brightness(preset: preset, enterElapsedMs: 60),
                peak / 2,
                accuracy: 0.001
            )
            // 120ms 达峰。
            XCTAssertEqual(
                WordShineEffect.brightness(preset: preset, enterElapsedMs: 120),
                peak,
                accuracy: 0.001
            )
            // 离开：120ms = 半亮（240ms 线性降）。
            XCTAssertEqual(
                WordShineEffect.brightness(preset: preset, enterElapsedMs: 120, exitElapsedMs: 120),
                peak / 2,
                accuracy: 0.001
            )
            XCTAssertEqual(
                WordShineEffect.brightness(preset: preset, enterElapsedMs: 120, exitElapsedMs: 240),
                0,
                accuracy: 0.001
            )
        }
    }

    /// ReduceMotion 辉光关闭（S4 §3）。
    func testReduceMotionDisablesShine() {
        XCTAssertTrue(WordShineEffect.isEnabled(reduceMotion: false))
        XCTAssertFalse(WordShineEffect.isEnabled(reduceMotion: true))
    }
}

import XCTest
@testable import RenderKit

/// 取色测试（S4 §4；S7 D33 #1）。
final class ColorExtractorTests: XCTestCase {
    /// RGB 容差断言。
    private func assertRGBClose(
        _ a: PixelRGB,
        _ b: PixelRGB,
        accuracy: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(abs(a.r - b.r), accuracy, "r", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(a.g - b.g), accuracy, "g", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(a.b - b.b), accuracy, "b", file: file, line: line)
    }

    private func pixels(_ color: PixelRGB, count: Int) -> [PixelRGB] {
        [PixelRGB](repeating: color, count: count)
    }

    /// 主色=最大簇均值、辅色=次大簇 ΔE>12（D33 #1）。
    func testPrimaryAndSecondary() throws {
        let red = PixelRGB(r: 220, g: 30, b: 30)
        let blue = PixelRGB(r: 30, g: 30, b: 200)
        let samples = pixels(red, count: 70) + pixels(blue, count: 30)
        let palette = try XCTUnwrap(ColorExtractor.palette(fromPixels: samples))
        assertRGBClose(palette.primary, red, accuracy: 1)
        assertRGBClose(palette.secondary, blue, accuracy: 1)
        XCTAssertGreaterThan(
            ColorExtractor.deltaE(
                ColorExtractor.srgbToLab(palette.primary),
                ColorExtractor.srgbToLab(palette.secondary)
            ),
            ColorExtractor.secondaryDeltaE
        )
    }

    /// 忽略 <1% 簇（D33 #1）。
    func testTinyClusterIgnored() throws {
        let red = PixelRGB(r: 220, g: 30, b: 30)
        let blue = PixelRGB(r: 30, g: 30, b: 200)
        let green = PixelRGB(r: 30, g: 220, b: 30)
        let samples = pixels(red, count: 998) + pixels(blue, count: 1) + pixels(green, count: 1)
        let palette = try XCTUnwrap(ColorExtractor.palette(fromPixels: samples))
        XCTAssertNotEqual(palette.secondary, green, "<1% 簇忽略")
        XCTAssertNotEqual(palette.secondary, blue, "<1% 簇忽略")
    }

    /// 辅色不足（ΔE≤12）→ 同色相明度变体（D33 #1）。
    func testLightnessVariantFallback() throws {
        let red = PixelRGB(r: 220, g: 30, b: 30)
        let samples = pixels(red, count: 100)
        let palette = try XCTUnwrap(ColorExtractor.palette(fromPixels: samples))
        assertRGBClose(palette.primary, red, accuracy: 1)
        let delta = ColorExtractor.deltaE(
            ColorExtractor.srgbToLab(palette.primary),
            ColorExtractor.srgbToLab(palette.secondary)
        )
        XCTAssertGreaterThan(delta, 0, "同色相明度变体可区分")
    }

    /// OctTree 快速路径（D33 #1）。
    func testOctTreeFastPath() throws {
        let red = PixelRGB(r: 220, g: 30, b: 30)
        let blue = PixelRGB(r: 30, g: 30, b: 200)
        let samples = pixels(red, count: 60) + pixels(blue, count: 40)
        let palette = try XCTUnwrap(ColorExtractor.palette(fromPixels: samples, algorithm: .octTree))
        assertRGBClose(palette.primary, red, accuracy: 2)
    }

    /// Lab 往返与 ΔE 自洽。
    func testLabRoundTrip() {
        let color = PixelRGB(r: 120, g: 80, b: 200)
        let back = ColorExtractor.labToSrgb(ColorExtractor.srgbToLab(color))
        assertRGBClose(back, color, accuracy: 1)
        XCTAssertEqual(
            ColorExtractor.deltaE(ColorExtractor.srgbToLab(color), ColorExtractor.srgbToLab(color)),
            0,
            accuracy: 0.001
        )
    }
}

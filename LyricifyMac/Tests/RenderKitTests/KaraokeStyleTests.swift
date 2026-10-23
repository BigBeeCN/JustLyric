import XCTest
@testable import RenderKit

/// 样式默认值测试（S4 §2.3；S7 D30 #3）。
final class KaraokeStyleTests: XCTestCase {
    /// D30 #3：MVP 默认值（M4 设置页暴露）。
    func testMVPDefaults() {
        let style = KaraokeStyle()
        XCTAssertEqual(style.floatHeight, 2, accuracy: 0.001)
        XCTAssertEqual(style.progressWidth, 8, accuracy: 0.001)
        XCTAssertEqual(style.unplayedOpacity, 0.55, accuracy: 0.001)
        XCTAssertEqual(style.fillSoftness, 1, accuracy: 0.001)
    }

    /// S4 §2.3 其余开关默认。
    func testSwitchDefaults() {
        let style = KaraokeStyle()
        XCTAssertFalse(style.floatEnabled)
        XCTAssertFalse(style.wordShine)
        XCTAssertTrue(style.animationEnabled)
        XCTAssertFalse(style.chineseRollingEasing)
        XCTAssertFalse(style.disableCJKKaraoke)
    }
}

import XCTest
@testable import RenderKit

/// 填充几何测试（S4 §2.2；S6 §4 边界单调；S7 D30 #1）。
final class FillGeometryTests: XCTestCase {
    private let layouts = [
        FillGeometry.SyllableLayout(startMs: 0, durationMs: 1000, width: 100),
        FillGeometry.SyllableLayout(startMs: 1000, durationMs: 1000, width: 100),
    ]

    /// 词内线性（D30 #1）：w=(now-start)/duration；边界=前缀宽+w×词宽。
    func testIntraWordLinear() {
        XCTAssertEqual(
            FillGeometry.fillBoundary(
                layouts: layouts, lineStartMs: 0, lineEndMs: 2000,
                nowMs: 500, lineWidth: 200
            ),
            50,
            accuracy: 0.001
        )
        XCTAssertEqual(
            FillGeometry.fillBoundary(
                layouts: layouts, lineStartMs: 0, lineEndMs: 2000,
                nowMs: 1500, lineWidth: 200
            ),
            150,
            accuracy: 0.001
        )
    }

    /// S6 §4：填充边界随 syllable 推进单调。
    func testBoundaryMonotonic() {
        var previous = -1.0
        for now in stride(from: 0.0, through: 2000, by: 25) {
            let boundary = FillGeometry.fillBoundary(
                layouts: layouts, lineStartMs: 0, lineEndMs: 2000,
                nowMs: now, lineWidth: 200
            )
            XCTAssertGreaterThanOrEqual(boundary, previous, "now=\(now)")
            previous = boundary
        }
    }

    /// 边界钳制：行前 0、行后总宽。
    func testBoundaryClamping() {
        XCTAssertEqual(
            FillGeometry.fillBoundary(
                layouts: layouts, lineStartMs: 0, lineEndMs: 2000,
                nowMs: -500, lineWidth: 200
            ),
            0
        )
        XCTAssertEqual(
            FillGeometry.fillBoundary(
                layouts: layouts, lineStartMs: 0, lineEndMs: 2000,
                nowMs: 5000, lineWidth: 200
            ),
            200
        )
    }

    /// 行级/线性模式：p × lineWidth。
    func testLineLevelLinear() {
        XCTAssertEqual(
            FillGeometry.fillBoundary(
                layouts: [], lineStartMs: 0, lineEndMs: 1000,
                nowMs: 250, lineWidth: 200
            ),
            50,
            accuracy: 0.001
        )
        XCTAssertEqual(
            FillGeometry.fillBoundary(
                layouts: layouts, lineStartMs: 0, lineEndMs: 2000,
                nowMs: 500, lineWidth: 200, linear: true
            ),
            50,
            accuracy: 0.001,
            "disableCJKKaraoke 等强制整行线性"
        )
    }

    /// D48：无 endMs 行（LRC）默认时长兑底——英文行不再瞬亮。
    func testDefaultSpanWhenNoEnd() {
        let p1 = FillGeometry.progress(lineStartMs: 0, lineEndMs: nil, nowMs: 1500)
        XCTAssertEqual(p1, 1500.0 / Double(FillGeometry.defaultLineSpanMs), accuracy: 0.001)
        XCTAssertEqual(FillGeometry.progress(lineStartMs: 0, lineEndMs: nil, nowMs: -1), 0)
    }

    /// 行进度 p（S4 §2.2.2）。
    func testProgress() {
        XCTAssertEqual(
            FillGeometry.progress(lineStartMs: 1000, lineEndMs: 2000, nowMs: 1500),
            0.5,
            accuracy: 0.001
        )
        XCTAssertEqual(FillGeometry.progress(lineStartMs: 0, lineEndMs: 1000, nowMs: -1), 0)
        XCTAssertEqual(FillGeometry.progress(lineStartMs: 0, lineEndMs: 1000, nowMs: 2000), 1)
    }
}

import Foundation

/// 逐字填充几何（S4 §2.2；S7 D30 #1：词内线性、词宽一次性缓存）。
public enum FillGeometry {
    /// 词块布局（宽度按最终布局字形宽一次性缓存）。
    public struct SyllableLayout: Equatable, Sendable {
        /// 起始（毫秒）。
        public var startMs: Int
        /// 时长（毫秒）。
        public var durationMs: Int
        /// 词宽（pt）。
        public var width: Double

        /// 创建词块布局。
        /// - Parameters:
        ///   - startMs: 起始毫秒。
        ///   - durationMs: 时长毫秒。
        ///   - width: 词宽 pt。
        public init(startMs: Int, durationMs: Int, width: Double) {
            self.startMs = startMs
            self.durationMs = durationMs
            self.width = width
        }
    }

    /// 行进度 `p ∈ [0,1]`（S4 §2.2.2：`p = (now - line.start) / (line.end - line.start)`）。
    /// - Parameters:
    ///   - lineStartMs: 行起始。
    ///   - lineEndMs: 行结束（缺省取词块末端）。
    ///   - nowMs: 当前媒体毫秒。
    /// - Returns: 进度。
    /// 无跨度行默认时长（ms；LRC 行无 endMs 兑底——常数记录免报）。
    public static let defaultLineSpanMs = 3000

    public static func progress(
        lineStartMs: Int?,
        lineEndMs: Int?,
        nowMs: Double
    ) -> Double {
        let start = Double(lineStartMs ?? 0)
        let end = Double(lineEndMs ?? Int(start) + defaultLineSpanMs)
        guard end > start else { return nowMs >= end ? 1 : 0 }
        let p = (nowMs - start) / (end - start)
        return min(1, max(0, p))
    }

    /// 填充边界（pt，S4 §2.2.2 词级定位 + 词内线性）。
    ///
    /// - 词级：定位当前词块 `i` 与词内插值 `w = (now - syl[i].start) / syl[i].duration`，
    ///   边界 = `前缀宽 + w × 词宽`；
    /// - 行级/`linear`（`disableCJKKaraoke` 等）：边界 = `p × lineWidth`；
    /// - 边界钳制于 `[0, 总宽]`（S4 §2.2.2）。
    /// - Parameters:
    ///   - layouts: 词块布局（升序、不重叠）。
    ///   - lineStartMs: 行起始。
    ///   - lineEndMs: 行结束。
    ///   - nowMs: 当前媒体毫秒。
    ///   - lineWidth: 行宽 pt（行级填充用）。
    ///   - linear: 强制整行线性。
    /// - Returns: 填充边界 pt。
    public static func fillBoundary(
        layouts: [SyllableLayout],
        lineStartMs: Int?,
        lineEndMs: Int?,
        nowMs: Double,
        lineWidth: Double,
        linear: Bool = false
    ) -> Double {
        guard !layouts.isEmpty, !linear else {
            return progress(lineStartMs: lineStartMs, lineEndMs: lineEndMs, nowMs: nowMs) * lineWidth
        }

        let totalWidth = layouts.reduce(0) { $0 + $1.width }
        guard nowMs >= Double(layouts[0].startMs) else { return 0 }

        var prefix = 0.0
        for (index, layout) in layouts.enumerated() {
            let start = Double(layout.startMs)
            let end = start + Double(layout.durationMs)
            if nowMs < start {
                // 块间隙：停在该块前缘。
                return prefix
            }
            if nowMs < end || index == layouts.count - 1 {
                let duration = max(1, end - start)
                let w = min(1, max(0, (nowMs - start) / duration))
                return min(totalWidth, prefix + w * layout.width)
            }
            prefix += layout.width
        }
        return totalWidth
    }
}

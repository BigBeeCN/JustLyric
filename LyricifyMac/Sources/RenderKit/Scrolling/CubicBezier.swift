import Foundation

/// 三次贝塞尔缓动求值（S4 §3：中文行 `cubic-bezier(0.25,0.1,0.25,1)`）。
public struct CubicBezier: Equatable, Sendable {
    /// 控制点 x1。
    public let x1: Double
    /// 控制点 y1。
    public let y1: Double
    /// 控制点 x2。
    public let x2: Double
    /// 控制点 y2。
    public let y2: Double

    /// 创建曲线。
    /// - Parameters:
    ///   - x1: 控制点 x1。
    ///   - y1: 控制点 y1。
    ///   - x2: 控制点 x2。
    ///   - y2: 控制点 y2。
    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    /// 求 y(x)（x ∈ [0,1]）。
    /// - Parameter x: 自变量。
    /// - Returns: 曲线值。
    public func value(at x: Double) -> Double {
        let clamped = min(1, max(0, x))
        guard clamped > 0, clamped < 1 else { return clamped }
        // 解 t 使 bezierX(t) = x（牛顿迭代 + 二分兜底）。
        var t = clamped
        for _ in 0 ..< 8 {
            let error = bezierX(t) - clamped
            if abs(error) < 1e-6 {
                break
            }
            let slope = bezierXSlope(t)
            if abs(slope) < 1e-6 {
                break
            }
            t -= error / slope
            t = min(1, max(0, t))
        }
        // 二分精化。
        var low = 0.0
        var high = 1.0
        for _ in 0 ..< 20 {
            let current = bezierX(t)
            if abs(current - clamped) < 1e-6 {
                break
            }
            if current < clamped {
                low = t
            } else {
                high = t
            }
            t = (low + high) / 2
        }
        return bezierY(t)
    }

    private func bezierX(_ t: Double) -> Double {
        3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t
    }

    private func bezierY(_ t: Double) -> Double {
        3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t
    }

    private func bezierXSlope(_ t: Double) -> Double {
        3 * (1 - t) * (1 - t) * x1
            + 6 * (1 - t) * t * (x2 - x1)
            + 3 * t * t * (1 - x2)
    }
}

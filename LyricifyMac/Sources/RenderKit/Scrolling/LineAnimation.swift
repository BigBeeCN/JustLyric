import Foundation

/// 滚动/浮起动画配置（S4 §3 七行为 + S5 v1 键直通；常数类 D27 #3 记录免报）。
public struct LineAnimationConfig: Sendable {
    /// 背景人声进入方向（`background_vocals_entering_direction`）。
    public enum EnteringDirection: String, Sendable {
        /// 自上。
        case up
        /// 自下。
        case down
        /// 自左。
        case left
        /// 自右。
        case right
    }

    /// 浮起开关（`karaoke_style_float`）。
    public var floatEnabled: Bool = false
    /// 浮起高度 pt（D30 #3：2）。
    public var floatHeight: Double = 2
    /// 拖拽回弹开关（`pulling`）。
    public var pullingEnabled: Bool = true
    /// 回弹反向位移 pt（S4 §3：3–5pt，取中 4）。
    public var pullingOffsetPt: Double = 4
    /// 回弹延迟 ms（`pulling_delay`）。
    public var pullingDelayMs: Double = 0
    /// 未唱行透明度（D30 #3：0.55）。
    public var unplayedOpacity: Double = 0.55
    /// 预下行透明度（`current_line_preplay_opacity`）。
    public var preplayOpacity: Double = 0.8
    /// 当前行缩放（`playing_zoom`，S4 §3 示例 1.08）。
    public var playingZoom: Double = 1.08
    /// 中文滚动缓动（`karaoke_chinese_easing`）。
    public var chineseRollingEasing: Bool = false
    /// 背景人声进入方向。
    public var backgroundVocalsEnteringDirection: EnteringDirection = .down
    /// 背景人声可重叠（`background_vocals_overlap`）。
    public var backgroundVocalsOverlap: Bool = false
    /// 系统减弱动态效果（ReduceMotion）。
    public var reduceMotion: Bool = false

    /// 创建配置。
    public init() {}
}

/// 行过渡计划（S4 §3 七行为的纯规划产物；应用层为 CA spring 域，S7 D30 #6）。
public enum LineTransitionPlanner {
    /// 行状态。
    public struct LineState: Equatable, Sendable {
        /// 滚动位移 pt（锚点相对）。
        public var offsetY: Double
        /// 浮起位移 pt（词级上移）。
        public var liftY: Double
        /// 透明度。
        public var opacity: Double
        /// 缩放。
        public var scale: Double

        /// 创建行状态。
        public init(offsetY: Double, liftY: Double, opacity: Double, scale: Double) {
            self.offsetY = offsetY
            self.liftY = liftY
            self.opacity = opacity
            self.scale = scale
        }
    }

    /// 动画曲线（滚动/浮起 spring 域）。
    public enum Curve: Equatable, Sendable {
        /// 无动画（ReduceMotion）。
        case none
        /// 弹簧（response, dampingRatio）。
        case spring(response: Double, damping: Double)
        /// 三次贝塞尔。
        case cubicBezier(CubicBezier)
    }

    /// 过渡计划。
    public struct Plan: Equatable, Sendable {
        /// 上一行。
        public var previous: LineState
        /// 当前行。
        public var current: LineState
        /// 预下行。
        public var preplay: LineState
        /// 换行滚动曲线。
        public var curve: Curve
        /// 回弹延迟 ms。
        public var pullingDelayMs: Double
        /// 背景人声进入位移。
        public var backgroundVocalEnterOffset: CGPoint

        /// 创建计划。
        public init(
            previous: LineState,
            current: LineState,
            preplay: LineState,
            curve: Curve,
            pullingDelayMs: Double,
            backgroundVocalEnterOffset: CGPoint
        ) {
            self.previous = previous
            self.current = current
            self.preplay = preplay
            self.curve = curve
            self.pullingDelayMs = pullingDelayMs
            self.backgroundVocalEnterOffset = backgroundVocalEnterOffset
        }
    }

    /// 换行滚动弹簧（S4 §3：response 0.45, damping 0.85）。
    public static let scrollSpring = (response: 0.45, damping: 0.85)
    /// 浮起弹簧（S4 §3：response 0.3, damping 0.7）。
    public static let liftSpring = (response: 0.3, damping: 0.7)
    /// 中文滚动缓动（S4 §3：cubic-bezier(0.25,0.1,0.25,1)）。
    public static let chineseEasing = CubicBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1)

    /// 生成计划。
    /// - Parameters:
    ///   - config: 配置。
    ///   - lineHeight: 行高 pt（滚动位移单位）。
    /// - Returns: 过渡计划。
    public static func plan(config: LineAnimationConfig, lineHeight: Double) -> Plan {
        let reduce = config.reduceMotion

        // 1 换行滚动 + 3 拖拽回弹（ReduceMotion：位移退化，S4 §3）。
        var previousY = -lineHeight
        if config.pullingEnabled, !reduce {
            previousY -= config.pullingOffsetPt
        }
        if reduce {
            previousY = 0
        }

        // 2 浮起 + 5 缩放 + 4 透明度。
        let current = LineState(
            offsetY: 0,
            liftY: reduce ? 0 : (config.floatEnabled ? -config.floatHeight : 0),
            opacity: 1,
            scale: reduce ? 1 : config.playingZoom
        )
        let previous = LineState(
            offsetY: previousY,
            liftY: 0,
            opacity: config.unplayedOpacity,
            scale: 1
        )
        let preplay = LineState(
            offsetY: reduce ? 0 : lineHeight,
            liftY: 0,
            opacity: config.preplayOpacity,
            scale: 1
        )

        // 6 背景人声进入方向。
        let enterOffset = switch config.backgroundVocalsEnteringDirection {
        case .up: CGPoint(x: 0, y: -lineHeight / 4)
        case .down: CGPoint(x: 0, y: lineHeight / 4)
        case .left: CGPoint(x: -lineHeight / 4, y: 0)
        case .right: CGPoint(x: lineHeight / 4, y: 0)
        }

        // 曲线：D30 #6 spring 域；ReduceMotion 无动画。
        let curve: Curve = if reduce {
            .none
        } else if config.chineseRollingEasing {
            .cubicBezier(chineseEasing)
        } else {
            .spring(response: scrollSpring.response, damping: scrollSpring.damping)
        }

        return Plan(
            previous: previous,
            current: current,
            preplay: preplay,
            curve: curve,
            pullingDelayMs: reduce ? 0 : config.pullingDelayMs,
            backgroundVocalEnterOffset: reduce ? .zero : enterOffset
        )
    }
}

/// SwiftUI spring(response:damping:) → CA `CASpringAnimation` 参数近似映射
/// （实现级记录：质量 1，`k=(2π/response)²`，`c=2ζ√k`）。
public enum SpringTimingMapper {
    /// 映射 CA 参数。
    /// - Parameters:
    ///   - response: 响应时间（秒）。
    ///   - damping: 阻尼比 ζ。
    /// - Returns: (mass, stiffness, dampingCA)。
    public static func caParameters(
        response: Double,
        damping: Double
    ) -> (mass: Double, stiffness: Double, dampingCA: Double) {
        let mass = 1.0
        let stiffness = pow(2 * Double.pi / max(response, 0.001), 2)
        let dampingCA = 2 * damping * sqrt(stiffness)
        return (mass, stiffness, dampingCA)
    }
}

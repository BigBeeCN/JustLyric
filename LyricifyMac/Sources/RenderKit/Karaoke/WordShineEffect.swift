import Foundation

/// 词辉光（S4 §3 TextWordShine；S7 D30 #2 预设系数与包络）。
///
/// - 预设 soft/normal/strong = 亮度系数 0.6/1.0/1.4、模糊 2/4/8pt（随字号缩放）；
/// - 亮度包络：进入 120ms 线性升、离开 240ms 线性降——三档时间一致；
/// - ReduceMotion 下辉光关闭（S4 §3）。
public struct WordShineEffect: Sendable {
    /// 辉光预设（`word_shine_effect_preset`）。
    public enum Preset: String, Sendable, CaseIterable {
        /// 柔和。
        case soft
        /// 标准。
        case normal
        /// 强烈。
        case strong

        /// 亮度系数（D30 #2）。
        public var brightnessFactor: Double {
            switch self {
            case .soft: 0.6
            case .normal: 1.0
            case .strong: 1.4
            }
        }

        /// 基准模糊 pt（17pt 字号；D30 #2）。
        public var baseBlurPt: Double {
            switch self {
            case .soft: 2
            case .normal: 4
            case .strong: 8
            }
        }
    }

    /// 进入时长（毫秒，D30 #2：三档一致）。
    public static let enterMs = 120.0
    /// 离开时长（毫秒，D30 #2：三档一致）。
    public static let exitMs = 240.0

    /// 亮度包络（进入线性升 / 离开线性降）。
    /// - Parameters:
    ///   - preset: 预设。
    ///   - enterElapsedMs: 进入后经过毫秒。
    ///   - exitElapsedMs: 离开后经过毫秒（`nil` = 未离开）。
    /// - Returns: 当前亮度系数。
    public static func brightness(
        preset: Preset,
        enterElapsedMs: Double,
        exitElapsedMs: Double? = nil
    ) -> Double {
        let peak = preset.brightnessFactor
        if let exitElapsedMs {
            let t = min(1, max(0, exitElapsedMs / exitMs))
            return peak * (1 - t)
        }
        let t = min(1, max(0, enterElapsedMs / enterMs))
        return peak * t
    }

    /// 模糊半径（随字号缩放：`base × size / 17`，基准见 S7 D30 #4）。
    /// - Parameters:
    ///   - preset: 预设。
    ///   - fontPointSize: 字号。
    /// - Returns: 模糊 pt。
    public static func blurPt(preset: Preset, fontPointSize: Double) -> Double {
        preset.baseBlurPt * fontPointSize / 17.0
    }

    /// ReduceMotion 下辉光关闭（S4 §3）。
    /// - Parameter reduceMotion: 系统减弱动态效果。
    /// - Returns: 是否启用辉光。
    public static func isEnabled(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}

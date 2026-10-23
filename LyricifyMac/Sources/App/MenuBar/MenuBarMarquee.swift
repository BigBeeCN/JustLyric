import Foundation

/// 菜单栏内容与时序（S4 §5；S7 D35：跑马灯 30pt/s、两端驻留 1.5s、内容=曲名-歌手）。
public enum MenuBarMarquee {
    /// 滚动速度（pt/s，D35）。
    public static let scrollSpeedPtsPerSecond: Double = 30
    /// 两端驻留（秒，D35）。
    public static let dwellSeconds: Double = 1.5

    /// 内容格式（D35：曲名-歌手；空项优雅降级）。
    /// - Parameters:
    ///   - title: 曲名。
    ///   - artist: 歌手。
    /// - Returns: `曲名 - 歌手` 形态。
    public static func content(title: String?, artist: String?) -> String {
        let t = (title ?? "").trimmingCharacters(in: .whitespaces)
        let a = (artist ?? "").trimmingCharacters(in: .whitespaces)
        switch (t.isEmpty, a.isEmpty) {
        case (true, true): return "未在播放"
        case (false, true): return t
        case (true, false): return a
        case (false, false): return "\(t) - \(a)"
        }
    }

    /// 跑马灯周期（秒）：驻留×2 + 单程×2（关键帧循环）。
    /// - Parameters:
    ///   - textWidth: 文本宽 pt。
    ///   - viewportWidth: 视口宽 pt。
    /// - Returns: 完整周期秒数；文本不超宽时为 0（不滚动）。
    public static func cycleSeconds(textWidth: Double, viewportWidth: Double) -> Double {
        guard textWidth > viewportWidth, viewportWidth > 0 else { return 0 }
        let travel = textWidth - viewportWidth
        let oneWay = travel / scrollSpeedPtsPerSecond
        return (oneWay + dwellSeconds) * 2
    }
}

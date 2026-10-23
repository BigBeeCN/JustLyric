import Foundation

/// 时间轴提供者协议（S7 D30 #5：渲染组件只认协议，禁止直读系统时钟）。
///
/// `MediaSession.TimelineProvider` 为唯一生产实现；组件经本协议注入，
/// 测试注入桩时钟保证确定性。
public protocol TimelineProviding: AnyObject {
    /// 当前媒体已播时长（毫秒）。
    /// - Parameter now: 外部注入的时钟读数（组件不得自行取系统时间）。
    /// - Returns: 媒体时间轴毫秒。
    func elapsed(now: TimeInterval) -> Int
}

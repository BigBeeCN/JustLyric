import Foundation

/// byland 状态机（S7 D35：贴边吸附半隐藏、悬停展开；S7 D39：边界四条固化）。
///
/// 状态图（M4 验收核对件）：
/// ```text
///            hoverEntered               hoverExited(延迟 0.8s)
///   halfHidden ─────────▶ expanded ─────────────────────▶ halfHidden
///       ▲                    │                                │
///       │   snapRequested    │ expand                         │ collapse
///       └────────────────────┴────────────────────────────────┘
/// ```
/// 边界（D39 固化）：① hoverExit 0.8s 防抖 ② 悬停中 collapse 忽略
/// ③ expand/snap 幂等 ④ 露出比 1/2。
public final class BylandStateMachine {
    /// 状态。
    public enum State: Equatable, Sendable {
        /// 贴边半隐藏。
        case halfHidden
        /// 悬停展开。
        case expanded
    }

    /// 事件。
    public enum Event: Sendable {
        /// 悬停进入。
        case hoverEntered
        /// 悬停退出（触发防抖计时）。
        case hoverExited
        /// 贴边吸附请求。
        case snapRequested
        /// 强制展开。
        case expand
        /// 强制收起。
        case collapse
    }

    /// 悬停退出延迟（秒；常数记录免报）。
    public static let hoverExitDelaySeconds: TimeInterval = 0.8

    /// 当前状态。
    public private(set) var state: State = .halfHidden
    /// 状态回调。
    public var onStateChange: ((State) -> Void)?

    private var hoverInside = false
    private var pendingCollapse: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.lyricifymac.byland")

    /// 创建状态机。
    public init() {}

    /// 处理事件。
    /// - Parameter event: 事件。
    public func handle(_ event: Event) {
        queue.sync {
            switch event {
            case .hoverEntered:
                hoverInside = true
                pendingCollapse?.cancel()
                pendingCollapse = nil
                transition(to: .expanded)
            case .hoverExited:
                hoverInside = false
                pendingCollapse?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    guard let self, !self.hoverInside else { return }
                    transition(to: .halfHidden)
                }
                pendingCollapse = work
                queue.asyncAfter(deadline: .now() + Self.hoverExitDelaySeconds, execute: work)
            case .snapRequested:
                hoverInside = false
                pendingCollapse?.cancel()
                transition(to: .halfHidden)
            case .expand:
                transition(to: .expanded)
            case .collapse:
                guard !hoverInside else { return }
                pendingCollapse?.cancel()
                transition(to: .halfHidden)
            }
        }
    }

    private func transition(to newState: State) {
        guard state != newState else { return }
        state = newState
        let callback = onStateChange
        queue.async {
            callback?(newState)
        }
    }
}

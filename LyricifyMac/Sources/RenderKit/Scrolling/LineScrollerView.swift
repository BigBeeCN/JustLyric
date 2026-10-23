import AppKit

/// 行滚动容器（S4 §3 LineScroller；S7 D30 #6：滚动/浮起 spring 域在 CA 层，
/// 与填充逐帧插值域分离，两域不得混用时间基准）。
///
/// ReduceMotion（S4 §3）：全部位移/缩放退化为透明度过渡——本类只挂 opacity 动画。
public final class LineScrollerView: NSView {
    /// 最近应用的计划（测试断言用）。
    public private(set) var appliedPlan: LineTransitionPlanner.Plan?

    /// 应用过渡计划（CA 层）。
    /// - Parameters:
    ///   - plan: 计划（`LineTransitionPlanner`）。
    ///   - previous: 上一行视图。
    ///   - current: 当前行视图。
    ///   - preplay: 预下行视图。
    public func apply(
        plan: LineTransitionPlanner.Plan,
        previous: NSView,
        current: NSView,
        preplay: NSView
    ) {
        appliedPlan = plan
        apply(plan: plan, to: previous, state: plan.previous, isCurrent: false)
        apply(plan: plan, to: current, state: plan.current, isCurrent: true)
        apply(plan: plan, to: preplay, state: plan.preplay, isCurrent: false)
    }

    // MARK: - 私有

    private func apply(
        plan: LineTransitionPlanner.Plan,
        to view: NSView,
        state: LineTransitionPlanner.LineState,
        isCurrent: Bool
    ) {
        view.wantsLayer = true
        guard let layer = view.layer else { return }
        layer.opacity = Float(state.opacity)

        switch plan.curve {
        case .none:
            // ReduceMotion：仅透明度过渡，无位移/缩放动画（S4 §3）。
            layer.position.y += CGFloat(state.offsetY)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.duration = 0.2
            layer.add(fade, forKey: "opacity")

        case let .spring(response, damping):
            let parameters = SpringTimingMapper.caParameters(response: response, damping: damping)
            let move = CASpringAnimation(keyPath: "position.y")
            move.mass = parameters.mass
            move.stiffness = parameters.stiffness
            move.damping = parameters.dampingCA
            move.fromValue = layer.position.y
            move.toValue = layer.position.y + state.offsetY + (isCurrent ? state.liftY : 0)
            layer.add(move, forKey: "position.y")

            if state.scale != 1 {
                let zoom = CASpringAnimation(keyPath: "transform.scale")
                zoom.mass = parameters.mass
                zoom.stiffness = parameters.stiffness
                zoom.damping = parameters.dampingCA
                zoom.fromValue = 1
                zoom.toValue = state.scale
                layer.add(zoom, forKey: "transform.scale")
            }

        case let .cubicBezier(bezier):
            let move = CABasicAnimation(keyPath: "position.y")
            move.timingFunction = CAMediaTimingFunction(
                controlPoints: Float(bezier.x1), Float(bezier.y1),
                Float(bezier.x2), Float(bezier.y2)
            )
            move.fromValue = layer.position.y
            move.toValue = layer.position.y + state.offsetY
            layer.add(move, forKey: "position.y")
        }
    }
}

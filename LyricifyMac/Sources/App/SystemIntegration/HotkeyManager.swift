import Carbon
import Foundation

/// 热键管理（S5 §2：Carbon `RegisterEventHotKey`；D35：默认不绑定，用户录制防冲突）。
///
/// > Note: Carbon 注册为系统级副作用，单元测试只覆盖绑定簿记（纯逻辑）；
/// > 真机注册验证归 M4-11 手测。
public final class HotkeyManager {
    /// 默认绑定（D35：**空**——默认不绑定原则不变）。
    public static let defaultBindings: [String: Hotkey] = [:]

    /// 当前绑定（action → hotkey）。
    public private(set) var bindings: [String: Hotkey] = [:]

    /// 创建管理器。
    public init() {}

    /// 绑定（去重冲突拒收）。
    /// - Parameters:
    ///   - action: 动作名。
    ///   - hotkey: 组合。
    /// - Returns: 是否成功。
    @discardableResult
    public func bind(action: String, hotkey: Hotkey) -> Bool {
        guard !bindings.values.contains(hotkey) else { return false }
        bindings[action] = hotkey
        return true
    }

    /// 解绑。
    /// - Parameter action: 动作名。
    public func unbind(action: String) {
        bindings.removeValue(forKey: action)
    }
}

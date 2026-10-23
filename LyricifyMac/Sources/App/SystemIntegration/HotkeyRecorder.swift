import Foundation

/// 热键组合（S5 §2；D35：默认不绑定，用户录制防冲突）。
public struct Hotkey: Equatable, Sendable {
    /// 按键码。
    public var keyCode: UInt32
    /// 修饰键（Carbon 常数位）。
    public var modifiers: UInt32

    /// 创建组合。
    /// - Parameters:
    ///   - keyCode: 按键码。
    ///   - modifiers: 修饰键。
    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// 热键录制状态机（S5 §2；常数/规则随验收报告报备，D16）。
///
/// 状态图：
/// ```text
///   idle ──start()──▶ recording ──capture(合法)──▶ idle（产出 hotkey）
///     ▲                  │
///     └──cancel()────────┤
///     └──timeout(10s)────┘
/// ```
public final class HotkeyRecorder {
    /// 录制超时（秒；常数记录免报）。
    public static let recordingTimeoutSeconds: TimeInterval = 10

    /// 状态。
    public enum State: Equatable, Sendable {
        /// 空闲。
        case idle
        /// 录制中。
        case recording
    }

    /// 当前状态。
    public private(set) var state: State = .idle
    /// 录制结果。
    public private(set) var captured: Hotkey?
    /// 冲突原因（测试/提示文案；系统保留命中 = `SystemReservedHotkeys.rejectionReason`）。
    public private(set) var lastRejection: String?
    /// 用户强制覆盖（D40 补充：否决权留给用户，默认禁止）。
    public var allowsSystemReservedOverride = false

    private var timeoutWork: DispatchWorkItem?

    /// 创建录制器。
    public init() {}

    /// 开始录制（已录制中重置计时）。
    public func start() {
        state = .recording
        captured = nil
        lastRejection = nil
        timeoutWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.state = .idle // 超时回空闲
        }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.recordingTimeoutSeconds,
            execute: work
        )
    }

    /// 提交按键（冲突判定，规则见类注释/待批 A15）。
    /// - Parameters:
    ///   - keyCode: 按键码。
    ///   - modifiers: 修饰键。
    ///   - existing: 用户既有绑定（冲突检测）。
    /// - Returns: 是否接受。
    @discardableResult
    public func capture(
        keyCode: UInt32,
        modifiers: UInt32,
        existing: [Hotkey] = [],
        reserved: [Hotkey] = SystemReservedHotkeys.reserved
    ) -> Bool {
        guard state == .recording else {
            lastRejection = "not-recording"
            return false
        }
        let hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers)
        // 规则 0（D40）：系统保留拒止；用户显式覆盖时放行（否决权在用户）。
        if reserved.contains(hotkey), !allowsSystemReservedOverride {
            lastRejection = SystemReservedHotkeys.rejectionReason
            return false
        }
        // 规则 1：非功能键必须带修饰键（防误触）。
        if modifiers == 0, !Self.functionKeyCodes.contains(keyCode) {
            lastRejection = "modifier-required"
            return false
        }
        // 规则 2：与用户既有绑定冲突拒收。
        if existing.contains(hotkey) {
            lastRejection = "duplicate"
            return false
        }
        captured = hotkey
        state = .idle
        timeoutWork?.cancel()
        lastRejection = nil
        return true
    }

    /// 取消录制。
    public func cancel() {
        timeoutWork?.cancel()
        state = .idle
        lastRejection = nil
    }

    /// 功能键码集（F1–F12，Apple 虚拟键码）。
    public static let functionKeyCodes: Set<UInt32> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
}

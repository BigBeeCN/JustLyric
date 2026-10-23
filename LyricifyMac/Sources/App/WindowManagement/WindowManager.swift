import Foundation

/// 显示面（S4 §5 四显示面）。
public enum DisplaySurface: String, CaseIterable, Sendable {
    /// 桌面歌词。
    case desktopLyrics
    /// 菜单栏。
    case menuBar
    /// 灵动条。
    case island
    /// 全屏歌词。
    case fullscreen
}

/// 窗口管理（S4 §5 显示面开关 + 记忆；S6 §5 手测项"4 显示面独立开关并记忆"）。
public struct WindowManager: Equatable, Sendable {
    /// 各面开关状态。
    public private(set) var enabled: [DisplaySurface: Bool]
    /// 记忆快照（持久化用）。
    public private(set) var memory: [String: Bool]

    /// 创建管理器。
    /// - Parameter memory: 已持久化记忆（恢复用）。
    public init(memory: [String: Bool] = [:]) {
        var state: [DisplaySurface: Bool] = [:]
        for surface in DisplaySurface.allCases {
            state[surface] = memory[surface.rawValue] ?? false
        }
        enabled = state
        self.memory = memory
    }

    /// 开关某面（并记忆，S6 §5）。
    /// - Parameters:
    ///   - surface: 显示面。
    ///   - on: 开关。
    public mutating func setEnabled(_ surface: DisplaySurface, on: Bool) {
        enabled[surface] = on
        memory[surface.rawValue] = on
    }

    /// 当前启用面。
    public var activeSurfaces: [DisplaySurface] {
        DisplaySurface.allCases.filter { enabled[$0] == true }
    }
}

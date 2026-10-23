import Foundation

/// 系统保留热键拒止清单（D40 A15-2 二级：**出稿待二次报批固化，不得自行扩大**）。
///
/// 依据：Apple HIG + macOS 默认保留组合（最小集，D40 点名清单）。
public enum SystemReservedHotkeys {
    // Carbon 修饰键位。
    private static let cmd: UInt32 = 0x100
    private static let shift: UInt32 = 0x200
    private static let option: UInt32 = 0x800
    private static let control: UInt32 = 0x1000

    /// 拒止清单（v1 草案 = D40 点名最小集，二次报批前不扩）。
    public static let reserved: [Hotkey] = [
        Hotkey(keyCode: 49, modifiers: cmd), // ⌘Space（Spotlight）
        Hotkey(keyCode: 48, modifiers: cmd), // ⌘Tab（应用切换）
        Hotkey(keyCode: 48, modifiers: cmd | shift), // ⌘⇧Tab
        Hotkey(keyCode: 50, modifiers: cmd), // ⌘`（同应用窗口循环）
        Hotkey(keyCode: 20, modifiers: cmd | shift), // ⌘⇧3（截屏）
        Hotkey(keyCode: 21, modifiers: cmd | shift), // ⌘⇧4
        Hotkey(keyCode: 23, modifiers: cmd | shift), // ⌘⇧5
        Hotkey(keyCode: 53, modifiers: cmd | option), // ⌘⌥Esc（强制退出）
        Hotkey(keyCode: 126, modifiers: control), // ⌃↑（调度中心）
        Hotkey(keyCode: 125, modifiers: control), // ⌃↓
        Hotkey(keyCode: 12, modifiers: cmd | control), // ⌘⌃Q（锁定屏幕）
    ]

    /// 拒止原因文案（UI 明示，D40 补充）。
    public static let rejectionReason = "系统保留"

    /// 是否命中拒止清单。
    /// - Parameter hotkey: 组合。
    /// - Returns: 命中。
    public static func isReserved(_ hotkey: Hotkey) -> Bool {
        reserved.contains(hotkey)
    }
}

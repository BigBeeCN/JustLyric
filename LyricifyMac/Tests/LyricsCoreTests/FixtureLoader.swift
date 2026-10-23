import Foundation

/// 测试夹具加载器（`Fixtures/` 目录，S1 §6）。
enum FixtureLoader {
    /// 夹具目录 URL。
    static func directoryURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // LyricsCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // LyricifyMac
            .appendingPathComponent("Fixtures")
    }

    /// 加载夹具文本。
    /// - Parameter name: 文件名（如 `lrc_basic.lrc`）。
    /// - Returns: 文件内容。
    static func load(_ name: String) throws -> String {
        try String(contentsOf: directoryURL().appendingPathComponent(name), encoding: .utf8)
    }
}

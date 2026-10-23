import Foundation

/// 测试夹具目录（`Fixtures/`，与 LyricsCoreTests 同源）。
enum FixtureLoader {
    /// 夹具目录 URL。
    static func directoryURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RenderKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // LyricifyMac
            .appendingPathComponent("Fixtures")
    }
}

import Foundation

/// 设置迁移器（S7 D35 ⭐：version + 迁移器；缺键回退组件默认禁崩）。
public enum SettingsMigrator {
    /// 当前 schema 版本。
    public static let currentVersion = 1

    /// 迁移：字典级顺序迁移（JSON 键值操作，禁崩）。
    /// - Parameters:
    ///   - json: 原始字典（mutable）。
    ///   - fromVersion: 起始版本（缺失按 0）。
    /// - Returns: 迁移后版本。
    @discardableResult
    public static func migrate(json: inout [String: Any], fromVersion: Int) -> Int {
        var version = fromVersion
        if version < 1 {
            // v1 基线：补齐 version 键；其余缺键由解码默认兜底（D35）。
            json["version"] = 1
            version = 1
        }
        return version
    }
}

/// 设置存储（`~/Library/Application Support/LyricifyMac/settings.json`，原子写）。
public final class SettingsStore: @unchecked Sendable {
    /// 文件 URL。
    public let fileURL: URL

    /// 创建存储。
    /// - Parameter fileURL: 文件 URL（默认标准路径）。
    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.fileURL = base
                .appendingPathComponent("JustLyric", isDirectory: true)
                .appendingPathComponent("settings.json")
        }
    }

    /// 载入（任何失败回退默认，禁崩——D35 ⭐）。
    /// - Returns: 设置。
    public func load() -> SettingsFile {
        guard let data = try? Data(contentsOf: fileURL) else { return SettingsFile() }
        // 字典级迁移先行。
        guard var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return SettingsFile() // 坏 JSON → 默认
        }
        let version = json["version"] as? Int ?? 0
        _ = SettingsMigrator.migrate(json: &json, fromVersion: version)
        guard let migrated = try? JSONSerialization.data(withJSONObject: json),
              let decoded = try? JSONDecoder().decode(SettingsFile.self, from: migrated)
        else {
            return SettingsFile()
        }
        return decoded
    }

    /// 保存（原子写；版本写入当前）。
    /// - Parameter settings: 设置。
    public func save(_ settings: SettingsFile) throws {
        var file = settings
        file.version = SettingsMigrator.currentVersion
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}

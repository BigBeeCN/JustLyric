import Foundation

/// 备份/恢复（S5 §2 v2：导出/导入 JSON；**复用 schema 版本与迁移器**（D46 提示 #3），不另起炉灶）。
public enum SettingsBackup {
    /// 导出（含 `version`）。
    /// - Parameter settings: 设置。
    /// - Returns: JSON 数据。
    public static func export(_ settings: SettingsFile) throws -> Data {
        var file = settings
        file.version = SettingsMigrator.currentVersion
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    /// 导入（迁移器先行；坏 JSON 抛错——比静默默认更安全，恢复场景需可感知失败）。
    /// - Parameter data: JSON 数据。
    /// - Returns: 迁移后的设置。
    public static func importSettings(_ data: Data) throws -> SettingsFile {
        guard var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw SettingsBackupError.invalidFormat
        }
        let version = json["version"] as? Int ?? 0
        _ = SettingsMigrator.migrate(json: &json, fromVersion: version)
        let migrated = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(SettingsFile.self, from: migrated)
    }
}

/// 备份错误。
public enum SettingsBackupError: Error, Equatable, Sendable {
    /// 格式非法。
    case invalidFormat
}

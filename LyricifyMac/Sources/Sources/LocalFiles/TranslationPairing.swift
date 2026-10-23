import Foundation

/// 翻译副文件配对（S7 D6：`.tr.lrc`/`.translated.lrc` 默认开）。
enum TranslationPairing {
    /// 查找副文件。
    /// - Parameter mainURL: 主歌词文件。
    /// - Returns: 副文件 URL；不存在时为 `nil`。
    static func secondaryURL(for mainURL: URL) -> URL? {
        let base = mainURL.deletingPathExtension()
        for suffix in ["tr.lrc", "translated.lrc"] {
            let candidate = base.appendingPathExtension(suffix)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}

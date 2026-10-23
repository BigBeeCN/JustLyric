import Foundation

/// amp-api JSON 信封解包（S7 D1/D26 #4/D27 #2）。
///
/// 取值路径定案（D27 #2，实测）：
/// 1. 主路径 `data[].relationships["syllable-lyrics"].data[].attributes.ttml`（逐字）；
/// 2. 回退 `relationships["lyrics"].data[].attributes.ttml`（行级）；
/// 3. `ttmlLocalizations` 忽略（D1 信封丢弃）；
/// 4. 递归查找降为**最后兜底**。
enum AppleTTMLEnvelope {
    /// 从信封提取 TTML。
    /// - Parameter data: amp-api 响应。
    /// - Returns: TTML 文本与质量档；不存在时为 `nil`。
    static func extractTTML(_ data: Data) -> (ttml: String, quality: LyricsQuality)? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if let ttml = structured(object, relationship: "syllable-lyrics") {
            return (ttml, .syllableSynced)
        }
        if let ttml = structured(object, relationship: "lyrics") {
            return (ttml, .lineSynced)
        }
        // 最后兜底：递归查找（跳过 ttmlLocalizations）。
        if let ttml = findTTML(in: object) {
            return (ttml, .syllableSynced)
        }
        return nil
    }

    /// 结构化路径：`data[].relationships[rel].data[].attributes.ttml`。
    private static func structured(_ object: Any, relationship: String) -> String? {
        guard let root = object as? [String: Any],
              let container = root["data"] as? [Any] else { return nil }
        for item in container {
            guard let entry = item as? [String: Any],
                  let relationships = entry["relationships"] as? [String: Any],
                  let relation = relationships[relationship] as? [String: Any],
                  let list = relation["data"] as? [Any] else { continue }
            for element in list {
                guard let node = element as? [String: Any],
                      let attributes = node["attributes"] as? [String: Any],
                      let ttml = attributes["ttml"] as? String else { continue }
                return ttml
            }
        }
        return nil
    }

    /// 递归查找（最后兜底；`ttmlLocalizations` 忽略）。
    private static func findTTML(in object: Any) -> String? {
        if let text = object as? String {
            return (text.contains("http://www.w3.org/ns/ttml") || text.contains("<tt")) ? text : nil
        }
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary where key != "ttmlLocalizations" {
                if let found = findTTML(in: value) {
                    return found
                }
            }
            return nil
        }
        if let array = object as? [Any] {
            for value in array {
                if let found = findTTML(in: value) {
                    return found
                }
            }
            return nil
        }
        return nil
    }
}

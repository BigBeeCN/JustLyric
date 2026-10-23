/// endMs 推定（S7 D49：管线通用步骤；渲染层禁止兜底，降级为断言）。
///
/// 规则（D49 定案）：`endMs` 缺失 → **下一行 `startMs` 推定**；末行 → `startMs + 3000ms`；
/// 推定结果标记于 ``LyricsData/inferredSpans``。
public enum TimeSpanInferrer {
    /// 末行默认跨度（ms，D49 定案）。
    public static let lastLineSpanMs = 3000

    /// 推定行时间跨度。
    /// - Parameter data: 歌词数据。
    /// - Returns: 全部行 `endMs` 就绪的数据。
    public static func infer(_ data: LyricsData) -> LyricsData {
        var result = data
        let starts = data.lines.map(\.startMs)
        var inferredCount = 0
        for index in data.lines.indices {
            guard data.lines[index].endMs == nil else { continue }
            let nextStart = index + 1 < starts.count ? starts[index + 1] : nil
            if let nextStart, let start = starts[index], nextStart > start {
                result.lines[index].endMs = nextStart
            } else if let start = starts[index] {
                result.lines[index].endMs = start + lastLineSpanMs
            }
            inferredCount += 1
        }
        result.inferredSpans = inferredCount
        return result
    }
}

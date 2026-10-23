/// 罗马音提供者（S7 D10：M1 占位、M5 实现）。
public protocol RomajiProvider {
    /// 为日语文本行生成罗马音/假名。
    /// - Parameter text: 日语文本。
    /// - Returns: 发音文本；M1 空实现恒为 `nil`。
    func pronunciation(for text: String) -> String?
}

/// M1 空实现（S7 D10：`pronunciation` 恒 nil）。
public struct NoopRomajiProvider: RomajiProvider {
    /// 创建空实现。
    public init() {}

    public func pronunciation(for text: String) -> String? {
        nil
    }
}

/// 管线配置（S2 §3 步骤 4–9 参数）。
public struct PipelineConfig {
    /// 源延迟（毫秒，S5 `lyrics_latency`）。
    public var sourceDelayMs: Int
    /// 会话延迟（毫秒，S3 `session_latency`）。
    public var sessionDelayMs: Int
    /// 显式标记策略。
    public var explicitPolicy: TextStages.ExplicitPolicy
    /// 简体优先。
    public var preferSimplified: Bool
    /// 繁体地区。
    public var region: ChineseRegion
    /// 长句切分开关。
    public var segmentationEnabled: Bool
    /// `title_lines` 设置覆盖。
    public var titleLinesOverride: Int?
    /// `ending_lines` 设置覆盖。
    public var endingLinesOverride: Int?
    /// 副翻译数据（D6：`attachTranslation` 输入）。
    public var secondaryTranslation: LyricsData?
    /// 罗马音提供者（S7 D10）。
    public var romajiProvider: RomajiProvider

    /// 创建管线配置。
    /// - Parameters:
    ///   - sourceDelayMs: 源延迟。
    ///   - sessionDelayMs: 会话延迟。
    ///   - explicitPolicy: 显式标记策略。
    ///   - preferSimplified: 简体优先。
    ///   - region: 繁体地区。
    ///   - segmentationEnabled: 长句切分开关。
    ///   - titleLinesOverride: `title_lines` 覆盖。
    ///   - endingLinesOverride: `ending_lines` 覆盖。
    ///   - secondaryTranslation: 副翻译数据。
    ///   - romajiProvider: 罗马音提供者。
    public init(
        sourceDelayMs: Int = 0,
        sessionDelayMs: Int = 0,
        explicitPolicy: TextStages.ExplicitPolicy = .keep,
        preferSimplified: Bool = true,
        region: ChineseRegion = .tw,
        segmentationEnabled: Bool = true,
        titleLinesOverride: Int? = nil,
        endingLinesOverride: Int? = nil,
        secondaryTranslation: LyricsData? = nil,
        romajiProvider: RomajiProvider = NoopRomajiProvider()
    ) {
        self.sourceDelayMs = sourceDelayMs
        self.sessionDelayMs = sessionDelayMs
        self.explicitPolicy = explicitPolicy
        self.preferSimplified = preferSimplified
        self.region = region
        self.segmentationEnabled = segmentationEnabled
        self.titleLinesOverride = titleLinesOverride
        self.endingLinesOverride = endingLinesOverride
        self.secondaryTranslation = secondaryTranslation
        self.romajiProvider = romajiProvider
    }
}

/// 翻译对齐（S2 §3 #8；S7 D6 `attachTranslation`：±1500ms 窗口取最近）。
public enum TranslationAligner {
    /// 就近窗口（毫秒，S2 §3 #8）。
    public static let windowMs = 1500

    /// 合并副翻译数据（S7 D6）：按时间戳就近（±1500ms，取最近）挂 `translation`。
    /// - Parameters:
    ///   - main: 主歌词数据。
    ///   - secondary: 副文件（翻译）数据。
    /// - Returns: 合并后的数据。
    public static func attachTranslation(main: LyricsData, secondary: LyricsData) -> LyricsData {
        var result = main
        result.lines = main.lines.map { line in
            guard line.translation == nil, let start = line.startMs else { return line }
            var best: (line: LyricsLine, distance: Int)?
            for candidate in secondary.lines {
                guard let candidateStart = candidate.startMs else { continue }
                let distance = abs(candidateStart - start)
                guard distance <= windowMs else { continue }
                if best == nil || distance < best!.distance {
                    best = (candidate, distance)
                }
            }
            guard let best else { return line }
            let copy = LyricsLine(
                startMs: line.startMs,
                endMs: line.endMs,
                text: line.text,
                translation: best.line.text,
                pronunciation: line.pronunciation,
                syllables: line.syllables,
                alignment: line.alignment,
                isBackgroundVocal: line.isBackgroundVocal
            )
            copy.subLine = line.subLine
            return copy
        }
        return result
    }
}

/// 优化管线编排（S2 §3：顺序固定 1→9）。
public enum LyricsPipeline {
    /// 运行管线。
    /// - Parameters:
    ///   - data: 歌词数据。
    ///   - config: 管线配置。
    /// - Returns: 优化后的数据。
    public static func run(_ data: LyricsData, config: PipelineConfig = PipelineConfig()) -> LyricsData {
        var result = data

        // 1 mergeSyllables
        result = SyllableStages.mergeSyllables(result)
        // 2 cleanInfoLines（D17 A1 约束 + 设置覆盖）
        result = TextStages.cleanInfoLines(
            result,
            titleLinesOverride: config.titleLinesOverride,
            endingLinesOverride: config.endingLinesOverride
        )
        // 3 downgradeIfNoSyllable
        result = SyllableStages.downgradeIfNoSyllable(result)
        // 4 applyOffsets（data.offsetMs + 源延迟 + 会话延迟；A5 正值=延后）
        let totalOffset = result.offsetMs + config.sourceDelayMs + config.sessionDelayMs
        if totalOffset != 0 {
            result = LyricsUtilities.applyOffset(result, ms: totalOffset)
        }
        // 5 explicitNormalize（A12）
        result = TextStages.explicitNormalize(result, policy: config.explicitPolicy)
        // 6 chineseNormalize
        result = TextStages.chineseNormalize(
            result,
            preferSimplified: config.preferSimplified,
            region: config.region,
            segmentationEnabled: config.segmentationEnabled
        )
        // 7 romaji（S7 D10：M1 空实现恒 nil）
        applyRomaji(&result, provider: config.romajiProvider)
        // 8 translationAlign（S7 D6：副翻译合并入口）
        if let secondary = config.secondaryTranslation {
            result = TranslationAligner.attachTranslation(main: result, secondary: secondary)
        }
        // 9 backgroundVocalDetect
        result = TextStages.backgroundVocalDetect(result)
        // 10 endMs 推定（S7 D49：管线通用步骤——渲染层禁兜底）
        result = TimeSpanInferrer.infer(result)

        return result
    }

    /// 步骤 7：romaji 占位（提供者返回 nil 时不动）。
    private static func applyRomaji(_ data: inout LyricsData, provider: RomajiProvider) {
        for line in data.lines where line.pronunciation == nil {
            line.pronunciation = provider.pronunciation(for: line.text)
        }
    }
}

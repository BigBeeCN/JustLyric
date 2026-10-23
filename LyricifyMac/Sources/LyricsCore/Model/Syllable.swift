/// 词/字块（S1 §1）。
public struct Syllable: Codable, Equatable, Sendable {
    /// 词文本。
    public var text: String
    /// 绝对起始时间（毫秒）。
    public var startMs: Int
    /// 时长（毫秒）。
    public var durationMs: Int
    /// 子词（如合成词细分）；无则为 `nil`。
    public var subSyllables: [Syllable]?

    /// 创建词块。
    /// - Parameters:
    ///   - text: 词文本。
    ///   - startMs: 绝对起始时间（毫秒）。
    ///   - durationMs: 时长（毫秒）。
    ///   - subSyllables: 子词数组，可选。
    public init(
        text: String,
        startMs: Int,
        durationMs: Int,
        subSyllables: [Syllable]? = nil
    ) {
        self.text = text
        self.startMs = startMs
        self.durationMs = durationMs
        self.subSyllables = subSyllables
    }
}

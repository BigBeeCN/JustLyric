/// 歌词行（S1 §1）。
///
/// > Note: 可变引用类型但按值语义使用（管线各步深拷贝）；标 `@unchecked Sendable`
/// > 以满足跨 actor 传递，内部不做并发写保护。
public final class LyricsLine: Codable, @unchecked Sendable {
    /// 行起始时间（毫秒）；未定时为 `nil`。
    public var startMs: Int?
    /// 行结束时间（毫秒）；未定时为 `nil`。
    public var endMs: Int?
    /// 原文（不含时间标记）。
    public var text: String
    /// 翻译。
    public var translation: String?
    /// 罗马音/注音。
    public var pronunciation: String?
    /// 词块数组；`nil` 表示行级同步。
    public var syllables: [Syllable]?
    /// 副行（背景人声）。
    public var subLine: LyricsLine?
    /// 行对齐方式，默认 `.center`。
    public var alignment: LyricsAlignment
    /// 是否为背景人声行。
    public var isBackgroundVocal: Bool

    /// 创建歌词行。
    /// - Parameters:
    ///   - startMs: 行起始时间（毫秒），可选。
    ///   - endMs: 行结束时间（毫秒），可选。
    ///   - text: 原文。
    ///   - translation: 翻译，可选。
    ///   - pronunciation: 罗马音/注音，可选。
    ///   - syllables: 词块数组；`nil` 表示行级同步。
    ///   - subLine: 副行（背景人声），可选。
    ///   - alignment: 对齐方式，默认 `.center`。
    ///   - isBackgroundVocal: 是否背景人声行，默认 `false`。
    public init(
        startMs: Int? = nil,
        endMs: Int? = nil,
        text: String,
        translation: String? = nil,
        pronunciation: String? = nil,
        syllables: [Syllable]? = nil,
        subLine: LyricsLine? = nil,
        alignment: LyricsAlignment = .center,
        isBackgroundVocal: Bool = false
    ) {
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
        self.translation = translation
        self.pronunciation = pronunciation
        self.syllables = syllables
        self.subLine = subLine
        self.alignment = alignment
        self.isBackgroundVocal = isBackgroundVocal
    }
}

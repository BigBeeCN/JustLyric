/// 歌词同步级别（S1 §1；S7 D21 三值）。
public enum SyncLevel: String, Codable, Sendable {
    /// 无同步（如纯文本兜底）。
    case unsynced
    /// 行级同步。
    case lineSynced
    /// 逐字/音节级同步。
    case syllableSynced
}

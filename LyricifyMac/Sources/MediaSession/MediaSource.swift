/// 媒体源（S3 §1）。
public protocol MediaSource: Sendable {
    /// 源标识（bundle id 或 "music"/"spotify" 直连）。
    var id: String { get }
    /// 事件流。
    var events: AsyncStream<MediaEvent> { get }
    /// 当前快照。
    func currentSnapshot() -> MediaSnapshot?
}

import Foundation
import LyricsCore

/// 分发通知兼容源（S3 §2：`com.apple.Music.playerInfo`/`com.apple.iTunes.playerInfo`）。
public final class DistributedNotificationSource: @unchecked Sendable {
    /// 监听通知名（S3 §2）。
    public static let notificationNames = [
        "com.apple.Music.playerInfo",
        "com.apple.iTunes.playerInfo",
    ]

    private let center: DistributedNotificationCenter?
    private let queue = DispatchQueue(label: "com.lyricifymac.distnote")
    private var observers: [NSObjectProtocol] = []

    /// 创建通知源。
    /// - Parameter center: 分发通知中心（测试可传 nil）。
    public init(center: DistributedNotificationCenter? = .default()) {
        self.center = center
    }

    /// 开始监听（回调只搬数据，状态机归聚合器，D28 原则）。
    /// - Parameter handler: 事件回调。
    /// - Returns: 停止函数。
    public func start(handler: @escaping @Sendable (MediaEvent) -> Void) -> @Sendable () -> Void {
        let queue = queue
        for name in Self.notificationNames {
            let observer = center?.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: nil
            ) { notification in
                let events = Self.events(fromUserInfo: notification.userInfo, at: Date().timeIntervalSince1970)
                for event in events {
                    handler(event)
                }
            }
            if let observer {
                observers.append(observer)
            }
        }
        _ = queue
        return { [weak self] in
            self?.stop()
        }
    }

    /// 停止监听。
    public func stop() {
        for observer in observers {
            center?.removeObserver(observer)
        }
        observers = []
    }

    /// userInfo → 事件（解析规则；供测试）。
    /// - Parameters:
    ///   - userInfo: 通知载荷。
    ///   - at: 事件时刻。
    /// - Returns: 事件数组。
    public static func events(
        fromUserInfo userInfo: [AnyHashable: Any]?,
        at: TimeInterval
    ) -> [MediaEvent] {
        guard let userInfo else { return [] }
        var result: [MediaEvent] = []

        let name = userInfo["Name"] as? String
        let artist = userInfo["Artist"] as? String
        let album = userInfo["Album"] as? String
        let totalMs = (userInfo["Total Time"] as? Int)
            ?? (userInfo["Total Time"] as? Double).map { Int($0) }

        if let name, !name.isEmpty {
            result.append(
                .track(
                    TrackRef(
                        title: name,
                        artists: [artist].compactMap { $0 },
                        album: album,
                        durationMs: totalMs,
                        bundleID: (userInfo["Bundle ID"] as? String) ?? "com.apple.Music"
                    )
                )
            )
        }

        if let state = userInfo["Player State"] as? String {
            let status: PlaybackState.Status = switch state.lowercased() {
            case "playing": .playing
            case "paused": .paused
            default: .stopped
            }
            result.append(.playback(PlaybackState(status: status, rate: status == .playing ? 1.0 : 0)))
        }
        return result
    }
}

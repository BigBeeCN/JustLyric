import AppKit
import Foundation
import LyricsCore

/// 封面缓存（S3 §6：LRU；S7 D29 #2：默认容量 200 张，键=track key，实现级可调）。
public final class ArtworkCache: @unchecked Sendable {
    /// 默认容量（张）。
    public static let defaultCapacity = 200

    private let capacity: Int
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    private var order: [String] = [] // LRU 顺序：最旧在前

    /// 创建封面缓存。
    /// - Parameter capacity: 容量（张）。
    public init(capacity: Int = ArtworkCache.defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    /// 存入封面（同键覆盖并刷新 LRU 位）。
    /// - Parameters:
    ///   - data: 封面数据。
    ///   - track: 曲目（键=track key）。
    public func store(_ data: Data, for track: TrackRef) {
        let key = TrackKeying.make(track)
        lock.lock()
        defer { lock.unlock() }
        if storage[key] != nil {
            order.removeAll { $0 == key }
        }
        storage[key] = data
        order.append(key)
        while order.count > capacity {
            let evicted = order.removeFirst()
            storage.removeValue(forKey: evicted)
        }
    }

    /// 取封面数据（命中刷新 LRU 位）。
    /// - Parameter track: 曲目。
    /// - Returns: 封面数据；未命中为 `nil`。
    public func imageData(for track: TrackRef) -> Data? {
        let key = TrackKeying.make(track)
        lock.lock()
        defer { lock.unlock() }
        guard let data = storage[key] else { return nil }
        order.removeAll { $0 == key }
        order.append(key)
        return data
    }

    /// 取封面图（S3 §6：`ArtworkData` → NSImage）。
    /// - Parameter track: 曲目。
    /// - Returns: 封面图。
    public func image(for track: TrackRef) -> NSImage? {
        imageData(for: track).flatMap { NSImage(data: $0) }
    }

    /// 当前条目数。
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}

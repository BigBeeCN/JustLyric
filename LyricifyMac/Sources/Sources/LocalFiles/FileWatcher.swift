import Foundation

/// 目录监听（LocalFiles 变化感知；去抖 300ms，常数细节 A17 待批）。
public final class FileWatcher: Sendable {
    private let directoryURL: URL
    private let debounceNs: UInt64
    private let handler: @Sendable () -> Void
    private let queue = DispatchQueue(label: "com.lyricifymac.filewatcher")

    /// 创建监听器。
    /// - Parameters:
    ///   - directoryURL: 目录。
    ///   - debounceMs: 去抖毫秒。
    ///   - handler: 变化回调（去抖后）。
    public init(directoryURL: URL, debounceMs: Int = 300, handler: @escaping @Sendable () -> Void) {
        self.directoryURL = directoryURL
        debounceNs = UInt64(max(0, debounceMs)) * 1_000_000
        self.handler = handler
    }

    /// 启动监听（返回停止闭包）。
    /// - Returns: 停止函数。
    public func start() -> @Sendable () -> Void {
        let fd = open(directoryURL.path, O_EVTONLY)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )
        var pending: DispatchWorkItem?
        source.setEventHandler { [handler, debounceNs] in
            pending?.cancel()
            let work = DispatchWorkItem(block: handler)
            pending = work
            DispatchQueue.global().asyncAfter(
                deadline: .now() + .nanoseconds(Int(debounceNs)),
                execute: work
            )
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        return { source.cancel() }
    }
}

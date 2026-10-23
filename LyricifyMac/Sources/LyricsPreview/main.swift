import App
import AppKit
import LyricsCore
import MediaSession
import RenderKit
import Sources

/// M4 手测窗显示侧：KaraokeTextView + D43 加固版 TimelineProvider 实时驱动。
let app = NSApplication.shared
app.setActivationPolicy(.regular)

final class ClockBox: TimelineProviding, @unchecked Sendable {
    let provider = TimelineProvider()
    func elapsed(now: TimeInterval) -> Int {
        provider.elapsed(now: now)
    }
}

final class Controller: NSObject {
    let panel = DesktopPanel(contentRect: NSRect(x: 200, y: 200, width: 800, height: 160))
    let clock = ClockBox()
    var textView: KaraokeTextView
    var lines: [LyricsLine] = []
    var lastTitle: String?
    // 持有权（教训：宿主流需持有 shim/stop，释放即断流）。
    private var shim: MediaRemoteShim?
    private var stopListener: (@Sendable () -> Void)?
    var lineIndex = 0
    var timer: Timer?

    override init() {
        textView = KaraokeTextView(line: LyricsLine(text: "取词中…"), clock: clock)
        textView.wrapsText = false // D44：长行走自适应字号（换行破坏 mask 几何）
        super.init()
        panel.contentView = textView
        panel.makeKeyAndOrderFront(nil)
    }

    func start() {
        // 时间轴喂样（adapter 流 → TimelineProvider，D43 加固路径）。
        let shim = MediaRemoteShim()
        self.shim = shim
        NSLog("preview: listener attached, adapter=%@", "\(shim.isAvailable)")
        stopListener = shim.startNowPlayingListener { [weak self] payload in
            NSLog("preview: payload keys=%@", payload.keys.sorted().joined(separator: ","))
            guard let self else { return }
            guard let elapsedMs = payload["elapsedMs"] as? Double else {
                NSLog("preview: elapsedMs cast FAILED")
                return
            }
            clock.provider.ingest(TimelineSample(
                elapsedMs: Int(elapsedMs),
                rate: 1.0,
                at: Date().timeIntervalSince1970
            ))
            if let title = payload["title"] as? String, title != lastTitle {
                lastTitle = title
                NSLog("preview: track change -> %@", title)
                lines = []
                lineIndex = -1
                Task { @MainActor in
                    self.textView.updateLine(LyricsLine(text: "《\(title)》 取词中…"))
                }
                fetch(title: title, artist: payload["artist"] as? String)
            }
        }
        // 60fps 帧驱动（填充域逐帧）。
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func fetch(title: String, artist: String?) {
        Task {
            let provider = LyricsProvider(adapters: [LRCLIBAdapter()])
            let track = TrackRef(title: title, artists: artist.map { [$0] } ?? [])
            let result = await provider.lyrics(
                for: track,
                pref: SourcePreferences(order: [.lrclib], minMatch: .low)
            )
            NSLog("preview: fetch result for %@: %@", title, "\(result)")
            await MainActor.run {
                if case let .found(data, _, _) = result {
                    self.lines = data.lines
                    self.lineIndex = -1
                    self.textView.updateLine(LyricsLine(text: "《\(title)》 歌词已就绪"))
                } else {
                    self.lines = []
                    self.textView.updateLine(LyricsLine(text: "《\(title)》 未找到歌词（LRCLIB 无收录）"))
                }
            }
        }
    }

    /// 显示延迟（D46 #3 校准生产化：生效偏移统一入口；每 2s 热读设置，校准即生效）。
    static var displayOffsetMs: Int {
        let now = Date().timeIntervalSince1970
        if now - lastOffsetRead > 2 {
            lastOffsetRead = now
            cachedOffset = CalibrationService().effectiveOffsetMs(sourceID: nil, bundleID: nil)
        }
        return cachedOffset
    }

    private static var lastOffsetRead: TimeInterval = 0
    private static var cachedOffset = 0

    func tick() {
        let now = Date().timeIntervalSince1970
        let elapsed = max(0, clock.provider.elapsed(now: now) - Self.displayOffsetMs)
        // 选当前行。
        if let idx = lines.lastIndex(where: {
            guard let start = $0.startMs else { return false }
            return elapsed >= start
        }), idx != lineIndex {
            lineIndex = idx
            MainActor.assumeIsolated {
                textView.updateLine(lines[idx])
            }
            // D45 取证：行文本 + 渲染 PNG 同步落盘（显示 vs 原文自动对照）。
            let text = lines[idx].text
            NSLog("preview: LINE text=[%@]", text)
            let png = MainActor.assumeIsolated {
                SnapshotRenderer.png(
                    of: textView,
                    size: CGSize(width: 800, height: 160),
                    dark: false
                )
            }
            let stamp = Int(Date().timeIntervalSince1970)
            try? png.write(to: URL(fileURLWithPath: "/tmp/lyric-trace-\(stamp).png"))
            try? text.write(
                to: URL(fileURLWithPath: "/tmp/lyric-trace-\(stamp).txt"),
                atomically: true,
                encoding: .utf8
            )
        }
        MainActor.assumeIsolated {
            textView.tick(now: now)
        }
    }
}

let controller = Controller()
controller.start()
app.activate(ignoringOtherApps: true)
app.run()

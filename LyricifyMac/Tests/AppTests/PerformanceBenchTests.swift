import LyricsCore
import XCTest
@testable import App
@testable import RenderKit
@testable import Sources

/// 性能自动化基准（S6 §1 A2/A4/A5/A6 自动化部分；A1/A7/A8 真机窗另测）。
final class PerformanceBenchTests: XCTestCase {
    private final class StubClock: TimelineProviding {
        func elapsed(now: TimeInterval) -> Int {
            Int(now * 1000)
        }
    }

    /// A2：缓存命中行切换响应 <300ms（日志打点口径）。
    func testA2CacheHitLatency() async throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bench-\(UUID().uuidString).sqlite")
        let cache = try LyricsCache(path: dbURL.path)
        defer { try? FileManager.default.removeItem(at: dbURL) }
        let track = TrackRef(title: "T", artists: ["A"])
        cache.save(
            track: track, source: .lrclib,
            raw: nil,
            lyrics: LyricsData(lines: [LyricsLine(text: "行")], syncLevel: .lineSynced, source: .lrc),
            quality: .lineSynced
        )
        let provider = LyricsProvider(adapters: [], cache: cache)
        let start = CFAbsoluteTimeGetCurrent()
        _ = await provider.lyrics(
            for: track,
            pref: SourcePreferences(order: [], minMatch: .low)
        )
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        XCTAssertLessThan(elapsedMs, 300, "A2 缓存命中 <300ms")
    }

    /// A4/A5：tick 持续 60fps 预算（<16.7ms/帧上限内，目标 <8ms）。
    func testA4A5FrameBudget() {
        let line = LyricsLine(
            startMs: 0,
            endMs: 240_000,
            text: String(repeating: "词", count: 40),
            syllables: (0 ..< 40).map { Syllable(text: "词", startMs: $0 * 6000, durationMs: 6000) }
        )
        let view = KaraokeTextView(line: line, clock: StubClock())
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 60)
        var total = 0.0
        let iterations = 300
        for step in 0 ..< iterations {
            let t = CFAbsoluteTimeGetCurrent()
            view.tick(now: Double(step) * 0.016)
            total += (CFAbsoluteTimeGetCurrent() - t) * 1000
        }
        let average = total / Double(iterations)
        XCTAssertLessThan(average, 8.0, "A5 单帧 CPU <8ms")
        XCTAssertLessThan(average, 16.7, "A4 可持续 60fps 预算")
    }

    /// A6：工作集 <300MB（合成压力：多视图+缓存存活）。
    func testA6MemoryFootprint() {
        var views: [KaraokeTextView] = []
        for index in 0 ..< 50 {
            let line = LyricsLine(
                startMs: 0,
                endMs: 1000,
                text: "压力行\(index)",
                syllables: [Syllable(text: "压", startMs: 0, durationMs: 1000)]
            )
            let view = KaraokeTextView(line: line, clock: StubClock())
            view.frame = CGRect(x: 0, y: 0, width: 800, height: 60)
            views.append(view)
        }
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        XCTAssertEqual(result, KERN_SUCCESS)
        let residentMB = Double(info.resident_size) / (1024 * 1024)
        XCTAssertLessThan(residentMB, 300, "A6 内存 <300MB")
        XCTAssertFalse(views.isEmpty)
    }
}

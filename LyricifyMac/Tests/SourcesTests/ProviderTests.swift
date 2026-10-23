import LyricsCore
import XCTest
@testable import Sources

/// LyricsProvider 测试（S2 §4；S6 §3-1 联动；S7 D25 #2）。
final class ProviderTests: XCTestCase {
    /// 线程安全计数。
    private final class Counter: @unchecked Sendable {
        var fetchCount = 0
    }

    /// mock 适配器。
    private struct MockAdapter: LyricsSourceAdapter {
        let id: SourceID
        let supportsSyllableSync: Bool
        let delayNs: UInt64
        let data: LyricsData?
        let counter: Counter

        func search(_ track: TrackRef) async throws -> [SourceCandidate] {
            [
                SourceCandidate(
                    sourceID: id,
                    id: "\(id.identifier)-1",
                    track: TrackRef(title: track.title, artists: track.artists),
                    quality: supportsSyllableSync ? .syllableSynced : .lineSynced
                ),
            ]
        }

        func fetch(_ candidate: SourceCandidate) async throws -> LyricsData {
            if delayNs > 0 {
                try? await Task.sleep(nanoseconds: delayNs)
            }
            counter.fetchCount += 1
            guard let data else { throw LyricsSourceError.noResult }
            return data
        }
    }

    private func makePreferences(order: [SourceID]) -> SourcePreferences {
        SourcePreferences(order: order, minMatch: .low)
    }

    /// 竞速：快源先用；高优先级慢源到达 → `lyricsUpgrade`（D25 #2）。
    func testRaceReturnsFirstThenUpgrades() async throws {
        let counter = Counter()
        let fast = MockAdapter(
            id: .lrclib, supportsSyllableSync: false, delayNs: 0,
            data: LyricsData(lines: [LyricsLine(text: "快源")], syncLevel: .lineSynced, source: .lrc),
            counter: counter
        )
        let slowHighPriority = MockAdapter(
            id: .appleTTML, supportsSyllableSync: true, delayNs: 200_000_000,
            data: LyricsData(
                lines: [LyricsLine(text: "慢源", syllables: [Syllable(text: "慢源", startMs: 0, durationMs: 500)])],
                syncLevel: .syllableSynced, source: .ttml
            ),
            counter: counter
        )
        let provider = LyricsProvider(adapters: [slowHighPriority, fast])
        let events = await provider.subscribe()

        let result = await provider.lyrics(
            for: TrackRef(title: "T", artists: ["A"]),
            pref: makePreferences(order: [.appleTTML, .lrclib])
        )
        guard case let .found(_, source, _) = result else {
            return XCTFail("应先命中快源")
        }
        XCTAssertEqual(source, .lrclib, "首个到达的结果先用")

        // 等待热替换事件。
        var upgraded: LyricsResult?
        let waiter = Task {
            for await event in events {
                if case let .lyricsUpgrade(value) = event {
                    upgraded = value
                    return
                }
            }
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        waiter.cancel()
        guard case let .found(_, upgradedSource, quality)? = upgraded else {
            return XCTFail("应收到 lyricsUpgrade")
        }
        XCTAssertEqual(upgradedSource, .appleTTML, "高优先级到达热替换")
        XCTAssertEqual(quality, .syllableSynced)
    }

    /// quality 标记（D25 #2）：行级源 → .lineSynced。
    func testQualityMarking() async {
        let adapter = MockAdapter(
            id: .lrclib, supportsSyllableSync: false, delayNs: 0,
            data: LyricsData(lines: [LyricsLine(text: "行")], syncLevel: .lineSynced, source: .lrc),
            counter: Counter()
        )
        let provider = LyricsProvider(adapters: [adapter])
        let result = await provider.lyrics(
            for: TrackRef(title: "T", artists: ["A"]),
            pref: makePreferences(order: [.lrclib])
        )
        XCTAssertEqual(result.quality, .lineSynced)
    }

    /// 无结果 → missing（降级链末端）。
    func testMissingWhenNoResult() async {
        let adapter = MockAdapter(
            id: .lrclib, supportsSyllableSync: false, delayNs: 0,
            data: nil, counter: Counter()
        )
        let provider = LyricsProvider(adapters: [adapter])
        let result = await provider.lyrics(
            for: TrackRef(title: "T", artists: ["A"]),
            pref: makePreferences(order: [.lrclib])
        )
        guard case let .missing(reason) = result else {
            return XCTFail("应 missing")
        }
        XCTAssertEqual(reason, .notFound)
    }

    /// 全部禁用 → noSourceEnabled。
    func testNoSourceEnabled() async {
        let provider = LyricsProvider(adapters: [])
        let result = await provider.lyrics(
            for: TrackRef(title: "T", artists: ["A"]),
            pref: makePreferences(order: [])
        )
        XCTAssertEqual(result.quality, .unknown)
        guard case .missing(.noSourceEnabled) = result else {
            return XCTFail("应 noSourceEnabled")
        }
    }

    /// 缓存命中不打源。
    func testCacheHitSkipsAdapters() async throws {
        let counter = Counter()
        let adapter = MockAdapter(
            id: .lrclib, supportsSyllableSync: false, delayNs: 0,
            data: LyricsData(lines: [LyricsLine(text: "行")], syncLevel: .lineSynced, source: .lrc),
            counter: counter
        )
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-cache-\(UUID().uuidString).sqlite")
        let cache = try LyricsCache(path: dbURL.path)
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let track = TrackRef(title: "T", artists: ["A"])
        cache.save(
            track: track, source: .lrclib,
            raw: nil,
            lyrics: LyricsData(lines: [LyricsLine(text: "缓存")], syncLevel: .lineSynced, source: .lrc),
            quality: .lineSynced
        )

        let provider = LyricsProvider(adapters: [adapter], cache: cache)
        let result = await provider.lyrics(for: track, pref: makePreferences(order: [.lrclib]))
        guard case let .found(data, _, _) = result else {
            return XCTFail("应命中缓存")
        }
        XCTAssertEqual(data.lines.first?.text, "缓存")
        XCTAssertEqual(counter.fetchCount, 0, "缓存命中不打源")
    }
}

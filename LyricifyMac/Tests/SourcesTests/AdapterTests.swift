import LyricsCore
import XCTest
@testable import Sources

/// 源适配协议层测试（S2 §1；S6 §3-1 mock 注入前置）。
final class AdapterTests: XCTestCase {
    /// mock 适配器（协议 conformance 冒烟）。
    private struct MockAdapter: LyricsSourceAdapter {
        let id: SourceID
        let supportsSyllableSync: Bool

        func search(_ track: TrackRef) async throws -> [SourceCandidate] {
            [SourceCandidate(sourceID: id, id: "mock-1", quality: .lineSynced)]
        }

        func fetch(_ candidate: SourceCandidate) async throws -> LyricsData {
            LyricsData(source: .lrc)
        }
    }

    /// 协议可用 + mock 注入往返。
    func testMockAdapterConformance() async throws {
        let adapter = MockAdapter(id: .lrclib, supportsSyllableSync: false)
        let candidates = try await adapter.search(TrackRef(title: "T", artists: ["A"]))
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].id, "mock-1")
        XCTAssertEqual(candidates[0].quality, .lineSynced)
        let data = try await adapter.fetch(candidates[0])
        XCTAssertEqual(data.source, .lrc)
    }

    /// SourceID 稳定标识符（缓存 source 列用）。
    func testSourceIDIdentifier() {
        XCTAssertEqual(SourceID.lrclib.identifier, "lrclib")
        XCTAssertEqual(SourceID.appleTTML.identifier, "apple_ttml")
        XCTAssertEqual(SourceID.localFiles.identifier, "local_files")
        XCTAssertEqual(SourceID.plugin("demo").identifier, "plugin:demo")
        XCTAssertEqual(SourceID.plugin("demo"), SourceID.plugin("demo"))
        XCTAssertNotEqual(SourceID.plugin("a"), SourceID.plugin("b"))
    }

    /// 质量档序（D25 #2）。
    func testQualityOrdering() {
        XCTAssertLessThan(LyricsQuality.unknown, .plain)
        XCTAssertLessThan(LyricsQuality.plain, .lineSynced)
        XCTAssertLessThan(LyricsQuality.lineSynced, .syllableSynced)
    }

    /// 偏好：禁用过滤 + 延迟表（S5 `lyrics_latency`）。
    func testSourcePreferences() {
        let preferences = SourcePreferences(
            order: [.lrclib, .appleTTML, .localFiles],
            minMatch: .low,
            disabled: [.appleTTML],
            lyricsLatencyBySource: [.lrclib: 150]
        )
        XCTAssertTrue(preferences.isEnabled(.lrclib))
        XCTAssertFalse(preferences.isEnabled(.appleTTML))
        XCTAssertEqual(preferences.minMatch, .low)
        XCTAssertEqual(preferences.lyricsLatencyBySource[.lrclib], 150)
    }
}

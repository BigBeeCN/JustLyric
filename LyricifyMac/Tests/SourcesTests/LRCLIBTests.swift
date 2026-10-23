import LyricsCore
import XCTest
@testable import Sources

/// LRCLIB 适配器测试（S2 §1.1；S7 D26 #1/#2 钉死）。
final class LRCLIBTests: XCTestCase {
    /// URL 构造 + UA 头（红线：仅 lrclib.net、UA 规范）。
    func testSearchURLAndUserAgent() async throws {
        let transport = StubTransport { request in
            XCTAssertEqual(request.url?.host, "lrclib.net")
            XCTAssertTrue(request.url?.path.hasSuffix("/api/search") == true)
            let query = request.url?.query ?? ""
            XCTAssertTrue(query.contains("track_name="))
            XCTAssertTrue(query.contains("artist_name="))
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "User-Agent"),
                LRCLIBAdapter.userAgent
            )
            return (Data("[]".utf8), StubTransport.response(url: request.url!, status: 200))
        }
        let adapter = LRCLIBAdapter(transport: transport)
        _ = try await adapter.search(TrackRef(title: "T", artists: ["A"]))
    }

    /// D26 #1：instrumental:true → isInstrumental/空行/.unsynced/.lrc。
    func testInstrumentalMapping() throws {
        let adapter = LRCLIBAdapter()
        let record = LRCLIBRecord(
            id: 1, trackName: "T", artistName: "A", albumName: nil,
            duration: nil, instrumental: true, plainLyrics: nil, syncedLyrics: nil
        )
        let data = try XCTUnwrap(try adapter.mapRecord(record))
        XCTAssertTrue(data.isInstrumental)
        XCTAssertTrue(data.lines.isEmpty)
        XCTAssertEqual(data.syncLevel, .unsynced)
        XCTAssertEqual(data.source, .lrc)
    }

    /// D26 #1：同时有 syncedLyrics 照常解析但标记仍置真。
    func testInstrumentalWithSyncedLyrics() throws {
        let adapter = LRCLIBAdapter()
        let record = LRCLIBRecord(
            id: 1, trackName: "T", artistName: "A", albumName: nil,
            duration: nil, instrumental: true,
            plainLyrics: nil, syncedLyrics: "[00:05.00]合成行"
        )
        let data = try XCTUnwrap(try adapter.mapRecord(record))
        XCTAssertTrue(data.isInstrumental, "标记仍置真")
        XCTAssertEqual(data.lines.count, 1, "照常解析")
    }

    /// D26 #2：plainLyrics → .unknown 纯文本路径 .unsynced 行。
    func testPlainLyricsMapping() throws {
        let adapter = LRCLIBAdapter()
        let record = LRCLIBRecord(
            id: 1, trackName: "T", artistName: "A", albumName: nil,
            duration: nil, instrumental: false,
            plainLyrics: "第一行\n第二行", syncedLyrics: nil
        )
        let data = try XCTUnwrap(try adapter.mapRecord(record))
        XCTAssertFalse(data.isInstrumental)
        XCTAssertEqual(data.syncLevel, .unsynced)
        XCTAssertEqual(data.source, .unknown)
        XCTAssertEqual(data.lines.map(\.text), ["第一行", "第二行"])
    }

    /// D26 #2：两字段皆缺且非纯音乐 = 无结果。
    func testNoResult() async throws {
        let adapter = LRCLIBAdapter()
        let record = LRCLIBRecord(
            id: 1, trackName: "T", artistName: "A", albumName: nil,
            duration: nil, instrumental: false, plainLyrics: nil, syncedLyrics: nil
        )
        XCTAssertNil(try adapter.mapRecord(record))

        let transport = StubTransport { request in
            (Data("{}".utf8), StubTransport.response(url: request.url!, status: 200))
        }
        let networked = LRCLIBAdapter(transport: transport)
        do {
            _ = try await networked.fetch(SourceCandidate(sourceID: .lrclib, id: "1", quality: .lineSynced))
            XCTFail("应抛 noResult")
        } catch let error as LyricsSourceError {
            XCTAssertEqual(error, .noResult)
        }
    }
}

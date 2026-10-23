import LyricsCore
import XCTest
@testable import Sources

/// AppleTTML 适配器测试（S2 §1.1、D1、D26 #4；红线：Keychain 必测）。
final class AppleTTMLTests: XCTestCase {
    /// D26 #4：信封解包出 TTML 后丢弃（不入 additionalInfo）。
    func testEnvelopeExtractionAndDiscard() async throws {
        let ttml = "<tt xmlns=\"http://www.w3.org/ns/ttml\"><body/></tt>"
        let envelope = """
        {"data":[{"id":"1","type":"songs","relationships":{"syllable-lyrics":{"data":[{"attributes":{"ttml":\(jsonEscape(ttml))}}]}}}]}
        """
        let transport = StubTransport { request in
            (Data(envelope.utf8), StubTransport.response(url: request.url!, status: 200))
        }
        let adapter = AppleTTMLAdapter(devToken: "dev", storefront: "us", transport: transport)
        let data = try await adapter.fetch(
            SourceCandidate(sourceID: .appleTTML, id: "1", quality: .syllableSynced)
        )
        XCTAssertEqual(data.source, .ttml)
        XCTAssertNil(data.additionalInfo, "D26 #4：信封丢弃")
    }

    /// D27 #2：主路径 syllable-lyrics 优先于 lyrics 回退。
    func testSyllableLyricsPrimaryPath() throws {
        let syllable = "<tt xmlns=\"http://www.w3.org/ns/ttml\"><body>逐字</body></tt>"
        let line = "<tt xmlns=\"http://www.w3.org/ns/ttml\"><body>行级</body></tt>"
        let envelope = """
        {"data":[{"id":"1","relationships":{
          "syllable-lyrics":{"data":[{"attributes":{"ttml":\(jsonEscape(syllable))}}]},
          "lyrics":{"data":[{"attributes":{"ttml":\(jsonEscape(line))}}]}
        }}]}
        """
        let extracted = try XCTUnwrap(AppleTTMLEnvelope.extractTTML(Data(envelope.utf8)))
        XCTAssertTrue(extracted.ttml.contains("逐字"))
        XCTAssertEqual(extracted.quality, .syllableSynced)
    }

    /// D27 #2：回退路径 lyrics（行级）。
    func testLyricsFallbackPath() throws {
        let line = "<tt xmlns=\"http://www.w3.org/ns/ttml\"><body>行级</body></tt>"
        let envelope = """
        {"data":[{"id":"1","relationships":{
          "lyrics":{"data":[{"attributes":{"ttml":\(jsonEscape(line))}}]}
        }}]}
        """
        let extracted = try XCTUnwrap(AppleTTMLEnvelope.extractTTML(Data(envelope.utf8)))
        XCTAssertTrue(extracted.ttml.contains("行级"))
        XCTAssertEqual(extracted.quality, .lineSynced)
    }

    /// D27 #2：ttmlLocalizations 忽略（D1 信封丢弃）。
    func testTtmlLocalizationsIgnored() {
        let ttml = "<tt xmlns=\"http://www.w3.org/ns/ttml\"><body/></tt>"
        let envelope = """
        {"data":[{"id":"1","attributes":{"ttmlLocalizations":{"x":{"ttml":\(jsonEscape(ttml))}}}}]}
        """
        XCTAssertNil(AppleTTMLEnvelope.extractTTML(Data(envelope.utf8)), "ttmlLocalizations 忽略")
    }

    /// D27 #2：storefront 解析 + Referer/Origin 头。
    func testStorefrontAndHeaders() async throws {
        let store = TokenStore(account: "test-storefront-\(UUID().uuidString)")
        defer { try? store.delete() }
        let transport = StubTransport { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "https://music.apple.com/")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://music.apple.com/")
            if request.url?.path.hasSuffix("/me/storefront") == true {
                let body = "{\"data\":[{\"id\":\"us\"}]}"
                return (Data(body.utf8), StubTransport.response(url: request.url!, status: 200))
            }
            return (Data("{\"data\":[]}".utf8), StubTransport.response(url: request.url!, status: 200))
        }
        let adapter = AppleTTMLAdapter(
            devToken: "dev", storefront: "us", tokenStore: store, transport: transport
        )
        let storefront = try await adapter.resolveStorefront()
        XCTAssertEqual(storefront, "us")
    }

    /// D26 #4：401 → tokenExpired + isTokenExpired 标记。
    func test401MarksTokenExpired() async throws {
        let transport = StubTransport { request in
            (Data(), StubTransport.response(url: request.url!, status: 401))
        }
        let adapter = AppleTTMLAdapter(devToken: "dev", storefront: "us", transport: transport)
        do {
            _ = try await adapter.fetch(SourceCandidate(sourceID: .appleTTML, id: "1", quality: .syllableSynced))
            XCTFail("应抛 tokenExpired")
        } catch let error as LyricsSourceError {
            XCTAssertEqual(error, .tokenExpired)
        }
        let expired = await adapter.isTokenExpired
        XCTAssertTrue(expired)
    }

    /// D26 #4：2xx 但空 lyrics = 无结果（非错误）。
    func testEmptyLyricsIsNoResult() async throws {
        let transport = StubTransport { request in
            (Data("{\"data\":[]}".utf8), StubTransport.response(url: request.url!, status: 200))
        }
        let adapter = AppleTTMLAdapter(devToken: "dev", storefront: "us", transport: transport)
        do {
            _ = try await adapter.fetch(SourceCandidate(sourceID: .appleTTML, id: "1", quality: .syllableSynced))
            XCTFail("应抛 noResult")
        } catch let error as LyricsSourceError {
            XCTAssertEqual(error, .noResult)
        }
    }

    /// 请求头：Bearer devToken + Media-User-Token（红线：MUT 来自 Keychain）。
    func testRequestHeaders() async throws {
        let store = TokenStore(account: "test-headers-\(UUID().uuidString)")
        try store.save("test-media-user-token")
        defer { try? store.delete() }

        let transport = StubTransport { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer dev")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Media-User-Token"), "test-media-user-token")
            XCTAssertEqual(request.url?.host, "amp-api.music.apple.com")
            return (Data("{\"data\":[]}".utf8), StubTransport.response(url: request.url!, status: 200))
        }
        let adapter = AppleTTMLAdapter(
            devToken: "dev", storefront: "us", tokenStore: store, transport: transport
        )
        _ = try? await adapter.search(TrackRef(title: "T", artists: ["A"]))
    }

    /// 红线必测（D25 协调）：Keychain 存取往返 + 遮罩 + 删除。
    func testKeychainRoundTrip() throws {
        let store = TokenStore(account: "test-roundtrip-\(UUID().uuidString)")
        XCTAssertNil(store.load())
        try store.save("secret-token-1234")
        XCTAssertEqual(store.load(), "secret-token-1234")
        XCTAssertEqual(store.maskedToken(), "••••1234")
        try store.delete()
        XCTAssertNil(store.load())
    }

    /// JSON 字符串转义（测试夹具用）。
    private func jsonEscape(_ text: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [text])
        let wrapped = String(data: data, encoding: .utf8)!
        return String(wrapped.dropFirst().dropLast())
    }
}

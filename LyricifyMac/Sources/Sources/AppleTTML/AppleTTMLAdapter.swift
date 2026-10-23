import Foundation
import LyricsCore

/// Apple Music TTML 适配器（S2 §1.1、S7 D1/D26 #4/D27 #2）。
///
/// > Important 红线（S0 §3 / S3 §7）：仅使用用户自持 MediaUserToken（Keychain，``TokenStore``）
/// > 调用公开 amp-api；401 → `isTokenExpired` 供 UI 提示，不绕过鉴权；
/// > 2xx 空 lyrics = `noResult`（非错误）；信封解包后丢弃（不入 `additionalInfo`）。
public actor AppleTTMLAdapter: LyricsSourceAdapter {
    public let id = SourceID.appleTTML
    public let supportsSyllableSync = true

    /// 令牌过期标记（S2 §1.1：供 UI 提示）。
    public private(set) var isTokenExpired = false

    private let transport: HTTPTransport
    private let tokenStore: TokenStore
    private let devToken: String
    private let storefront: String
    private let language: String

    /// 创建适配器。
    /// - Parameters:
    ///   - devToken: 开发者令牌（`Authorization: Bearer`）。
    ///   - storefront: 商店区（如 `us`/`cn`；可经 `resolveStorefront()` 解析）。
    ///   - language: 语言参数 `l`（常数类 D27 #3 免报，记录于 decisions）。
    ///   - tokenStore: MediaUserToken 存储（Keychain）。
    ///   - transport: HTTP 传输层。
    public init(
        devToken: String,
        storefront: String,
        language: String = "en-US",
        tokenStore: TokenStore = TokenStore(),
        transport: HTTPTransport = URLSessionTransport()
    ) {
        self.devToken = devToken
        self.storefront = storefront
        self.language = language
        self.tokenStore = tokenStore
        self.transport = transport
    }

    // MARK: - LyricsSourceAdapter

    /// 搜索（D27 #2 端点定案：`?term={q}&types=songs&limit={n}&l={lang}`）。
    public func search(_ track: TrackRef) async throws -> [SourceCandidate] {
        let term = ([track.title] + track.artists).joined(separator: " ")
        let data = try await get(
            host: "amp-api.music.apple.com",
            path: "/v1/catalog/\(storefront)/search",
            query: [
                URLQueryItem(name: "term", value: term),
                URLQueryItem(name: "types", value: "songs"),
                URLQueryItem(name: "limit", value: "5"),
                URLQueryItem(name: "l", value: language),
            ]
        )
        guard let songs = extractSongs(data) else { return [] }
        return songs.map { songID in
            SourceCandidate(sourceID: .appleTTML, id: songID, quality: .syllableSynced)
        }
    }

    /// 取词（D27 #2：歌曲详情 `?include[songs]=syllable-lyrics&l={lang}&extend=ttmlLocalizations`；
    /// 逐字主路径 → 行级回退 → 递归兜底；空 = `noResult`）。
    public func fetch(_ candidate: SourceCandidate) async throws -> LyricsData {
        do {
            let envelope = try await get(
                host: "amp-api.music.apple.com",
                path: "/v1/catalog/\(storefront)/songs/\(candidate.id)",
                query: [
                    URLQueryItem(name: "include[songs]", value: "syllable-lyrics"),
                    URLQueryItem(name: "l", value: language),
                    URLQueryItem(name: "extend", value: "ttmlLocalizations"),
                ]
            )
            guard let extracted = AppleTTMLEnvelope.extractTTML(envelope) else {
                // D26 #4：2xx 但空 lyrics = 无结果（非错误）。
                throw LyricsSourceError.noResult
            }
            return TTMLParser.parse(extracted.ttml)
        } catch LyricsSourceError.noResult {
            // 兜底端点（直出 TTML，S2 §1.1）。
            let ttmlData = try await get(
                host: "music.apple.com",
                path: "/lyric-ttml-internal/\(candidate.id)",
                query: []
            )
            guard let ttml = String(data: ttmlData, encoding: .utf8),
                  ttml.contains("http://www.w3.org/ns/ttml")
            else {
                throw LyricsSourceError.noResult
            }
            return TTMLParser.parse(ttml)
        }
    }

    /// 解析 storefront（D27 #2：`GET /v1/me/storefront`）。
    /// - Returns: 商店区代码（如 `us`）。
    public func resolveStorefront() async throws -> String {
        let data = try await get(
            host: "amp-api.music.apple.com",
            path: "/v1/me/storefront",
            query: []
        )
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any],
              let list = root["data"] as? [Any],
              let first = list.first as? [String: Any],
              let storefrontID = first["id"] as? String
        else {
            throw LyricsSourceError.noResult
        }
        return storefrontID
    }

    // MARK: - 私有

    private func extractSongs(_ data: Data) -> [String]? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              let results = dictionary["results"] as? [String: Any],
              let songs = results["songs"] as? [String: Any],
              let data = songs["data"] as? [Any] else { return nil }
        return data.compactMap { ($0 as? [String: Any])?["id"] as? String }
    }

    private func get(
        host: String,
        path: String,
        query: [URLQueryItem]
    ) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = query.isEmpty ? nil : query

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(devToken)", forHTTPHeaderField: "Authorization")
        // D27 #2：Referer/Origin = music.apple.com。
        request.setValue("https://music.apple.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://music.apple.com/", forHTTPHeaderField: "Origin")
        if let token = tokenStore.load(), !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Media-User-Token")
        }

        let (data, response) = try await transport.data(for: request)
        switch response.statusCode {
        case 200 ..< 300:
            isTokenExpired = false
            return data
        case 401:
            isTokenExpired = true // S2 §1.1：标记供 UI 提示
            throw LyricsSourceError.tokenExpired
        default:
            throw LyricsSourceError.httpStatus(response.statusCode)
        }
    }
}

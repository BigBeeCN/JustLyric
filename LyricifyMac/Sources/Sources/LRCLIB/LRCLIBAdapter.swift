import Foundation
import LyricsCore

/// LRCLIB 适配器（S2 §1.1；[红线-P1] 仅 `lrclib.net` 开放 API、UA 头规范、无遥测）。
///
/// 映射钉死（S7 D26）：
/// - `instrumental:true` → `{isInstrumental:true, lines:[], syncLevel:.unsynced, source:.lrc}`，
///   同时有 `syncedLyrics` 照常解析但标记仍置真；
/// - `plainLyrics` → `.unknown` 纯文本路径产出 `.unsynced` 行；
/// - 两字段皆缺且非纯音乐 → `noResult`。
public struct LRCLIBAdapter: LyricsSourceAdapter {
    public let id = SourceID.lrclib
    public let supportsSyllableSync = false

    /// API 基址（红线：仅 lrclib.net）。
    private static let baseURL = URL(string: "https://lrclib.net/api")!

    /// UA 头（D27 #1：单点见 `UserAgent`；占位不得出正式构建，P5 发版检查项）。
    public static let userAgent = UserAgent.current

    private let transport: HTTPTransport

    /// 创建适配器。
    /// - Parameter transport: HTTP 传输层（默认 URLSession）。
    public init(transport: HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    // MARK: - LyricsSourceAdapter

    public func search(_ track: TrackRef) async throws -> [SourceCandidate] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artists.first ?? ""),
        ]
        if let album = track.album {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        if let durationMs = track.durationMs {
            items.append(URLQueryItem(name: "duration", value: String(durationMs / 1000)))
        }
        let data = try await get(path: "search", query: items)
        let records = (try? JSONDecoder().decode([LRCLIBRecord].self, from: data)) ?? []
        return records.compactMap { record in
            guard let recordID = record.id else { return nil }
            return SourceCandidate(
                sourceID: .lrclib,
                id: String(recordID),
                track: TrackRef(
                    title: record.trackName ?? "",
                    artists: [record.artistName].compactMap { $0 },
                    album: record.albumName,
                    durationMs: record.duration.map { Int($0 * 1000) }
                ),
                preview: previewText(of: record),
                quality: quality(of: record)
            )
        }
    }

    public func fetch(_ candidate: SourceCandidate) async throws -> LyricsData {
        let data = try await get(path: "get/\(candidate.id)", query: [])
        let record = try JSONDecoder().decode(LRCLIBRecord.self, from: data)
        guard let lyrics = try mapRecord(record) else {
            throw LyricsSourceError.noResult
        }
        return lyrics
    }

    // MARK: - D26 映射

    /// 记录 → 歌词数据（D26 #1/#2 钉死）。
    func mapRecord(_ record: LRCLIBRecord) throws -> LyricsData? {
        if record.instrumental == true {
            // D26 #1：纯音乐；同时有 syncedLyrics 照常解析但标记仍置真。
            if let synced = record.syncedLyrics, !synced.isEmpty {
                var data = LrcParser.parse(synced)
                data.isInstrumental = true
                return data
            }
            return LyricsData(
                lines: [],
                syncLevel: .unsynced,
                isInstrumental: true,
                source: .lrc
            )
        }
        if let synced = record.syncedLyrics, !synced.isEmpty {
            return LrcParser.parse(synced)
        }
        if let plain = record.plainLyrics, !plain.isEmpty {
            // D26 #2：走 D20(b) .unknown 纯文本路径产出 .unsynced 行。
            return parse(plain, type: .unknown)
        }
        return nil // D26 #2：两字段皆缺且非纯音乐 = 无结果
    }

    // MARK: - 私有

    private func get(path: String, query: [URLQueryItem]) async throws -> Data {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components.url!)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await transport.data(for: request)
        switch response.statusCode {
        case 200 ..< 300:
            return data
        case 404:
            throw LyricsSourceError.noResult
        default:
            throw LyricsSourceError.httpStatus(response.statusCode)
        }
    }

    private func previewText(of record: LRCLIBRecord) -> String? {
        let source = record.plainLyrics ?? record.syncedLyrics
        return source?
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("[") }
    }

    private func quality(of record: LRCLIBRecord) -> LyricsQuality {
        if record.syncedLyrics?.isEmpty == false {
            return .lineSynced
        }
        if record.plainLyrics?.isEmpty == false {
            return .plain
        }
        return .unknown
    }
}

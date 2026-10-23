import Foundation
import LyricsCore

/// 本地歌词文件适配器（S2 §1.1、D6、D20、D26 #3）。
public struct LocalFilesAdapter: LyricsSourceAdapter {
    public let id = SourceID.localFiles
    public let supportsSyllableSync = true

    /// 歌词文件扩展名（S1 全格式）。
    private static let lyricExtensions: Set<String> = ["lrc", "krc", "qrc", "yrc", "ttml", "json", "txt"]

    private let directories: [URL]
    private let minMatch: MatchLevel
    private let translationPairingEnabled: Bool

    /// 创建适配器。
    /// - Parameters:
    ///   - directories: 用户目录列表（S5 `sources.local_files.paths`）。
    ///   - minMatch: 最低档（D26 #3）。
    ///   - translationPairingEnabled: 翻译副文件配对（D6 默认开）。
    public init(
        directories: [URL],
        minMatch: MatchLevel,
        translationPairingEnabled: Bool = true
    ) {
        self.directories = directories
        self.minMatch = minMatch
        self.translationPairingEnabled = translationPairingEnabled
    }

    // MARK: - LyricsSourceAdapter

    public func search(_ track: TrackRef) async throws -> [SourceCandidate] {
        var candidates: [SourceCandidate] = []
        for fileURL in lyricFiles() {
            guard let meta = metadata(of: fileURL, track: track) else { continue }
            candidates.append(
                SourceCandidate(
                    sourceID: .localFiles,
                    id: fileURL.path,
                    track: TrackRef(
                        title: meta.title ?? "",
                        artists: meta.artists,
                        album: meta.album,
                        durationMs: meta.durationMs
                    ),
                    preview: nil,
                    quality: quality(of: fileURL)
                )
            )
        }
        return candidates
    }

    public func fetch(_ candidate: SourceCandidate) async throws -> LyricsData {
        let fileURL = URL(fileURLWithPath: candidate.id)
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        var data = parse(raw)

        // D6：翻译副文件配对（默认开）→ attachTranslation。
        if translationPairingEnabled,
           let secondaryURL = TranslationPairing.secondaryURL(for: fileURL),
           let secondaryRaw = try? String(contentsOf: secondaryURL, encoding: .utf8)
        {
            let secondary = parse(secondaryRaw)
            data = TranslationAligner.attachTranslation(main: data, secondary: secondary)
        }
        return data
    }

    // MARK: - 监听

    /// 创建目录监听器（变化回调去抖）。
    /// - Parameter handler: 变化回调。
    /// - Returns: 停止函数数组。
    public func watchDirectories(handler: @escaping @Sendable () -> Void) -> [@Sendable () -> Void] {
        directories.map { directory in
            FileWatcher(directoryURL: directory, handler: handler).start()
        }
    }

    // MARK: - 私有

    private func lyricFiles() -> [URL] {
        let manager = FileManager.default
        var result: [URL] = []
        for directory in directories {
            let found = (try? manager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []
            result.append(contentsOf: found.filter { Self.lyricExtensions.contains($0.pathExtension.lowercased()) })
        }
        return result.sorted { $0.path < $1.path }
    }

    /// 文件元数据：内嵌（D20 trackMeta）优先，文件名三模式兜底（D26 #3）。
    private func metadata(of fileURL: URL, track: TrackRef) -> TrackMeta? {
        let raw = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        if let embedded = parse(raw).trackMeta, embedded.title != nil || !embedded.artists.isEmpty,
           FilenameMatcher.isAccepted(
               candidate: (embedded.title ?? "", embedded.artists),
               track: track,
               minMatch: minMatch
           ) || embeddedMatches(embedded, track)
        {
            return embedded
        }
        for candidate in FilenameMatcher.candidates(fromFilename: fileURL.lastPathComponent) {
            if FilenameMatcher.isAccepted(candidate: candidate, track: track, minMatch: minMatch) {
                return TrackMeta(title: candidate.title, artists: candidate.artists)
            }
        }
        return nil
    }

    /// 内嵌元数据直匹配（含艺人档达标的弱曲名匹配）。
    private func embeddedMatches(_ meta: TrackMeta, _ track: TrackRef) -> Bool {
        let (name, artist) = FilenameMatcher.matchLevel(
            of: (meta.title ?? "", meta.artists),
            against: track
        )
        if let name, name >= minMatch {
            return true
        }
        if let artist, artist >= minMatch, let name, name >= .low {
            return true
        }
        return false
    }

    private func quality(of fileURL: URL) -> LyricsQuality {
        let raw = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        switch parse(raw).syncLevel {
        case .syllableSynced: return .syllableSynced
        case .lineSynced: return .lineSynced
        case .unsynced: return .plain
        }
    }
}

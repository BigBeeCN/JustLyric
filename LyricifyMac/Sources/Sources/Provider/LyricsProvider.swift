import Foundation
import LyricsCore

/// 缺失原因（S2 §4 降级链末端）。
public enum MissingReason: Sendable, Equatable {
    /// 无启用源。
    case noSourceEnabled
    /// 全部源失败。
    case allSourcesFailed
    /// 源均无结果。
    case notFound
}

/// 取词结果（S7 D25 #2：各级结果带 `quality` 标记）。
public enum LyricsResult: Sendable {
    /// 命中（含纯音乐：`data.isInstrumental`，D26 #1）。
    case found(data: LyricsData, source: SourceID, quality: LyricsQuality)
    /// 无歌词（降级链末端）。
    case missing(reason: MissingReason)

    /// 质量标记（`missing` 为 `.unknown`）。
    public var quality: LyricsQuality {
        switch self {
        case let .found(_, _, quality): quality
        case .missing: .unknown
        }
    }
}

/// 编排事件（S7 D25 #2：`lyricsUpgrade` 显式命名，供 UI 与单测订阅）。
public enum LyricsProviderEvent: Sendable {
    /// 热替换：更高优先级结果到达。
    case lyricsUpgrade(LyricsResult)
}

/// 取词编排器（S2 §4：并发竞速 → 首个满足 `minMatch` 先用 → 高优先级热替换；
/// 预取 `Prepare`；缓存联动；降级链 逐字→行同步→plain→无歌词）。
public actor LyricsProvider {
    private let adapters: [any LyricsSourceAdapter]
    private let cache: LyricsCache?
    private let breakers: [String: CircuitBreaker]
    private var subscribers: [UUID: AsyncStream<LyricsProviderEvent>.Continuation] = [:]

    /// 创建编排器。
    /// - Parameters:
    ///   - adapters: 源适配器（内置三源 + 插件位）。
    ///   - cache: 歌词缓存（可选）。
    public init(adapters: [any LyricsSourceAdapter], cache: LyricsCache? = nil) {
        self.adapters = adapters
        self.cache = cache
        var breakers: [String: CircuitBreaker] = [:]
        for adapter in adapters {
            breakers[adapter.id.identifier] = CircuitBreaker()
        }
        self.breakers = breakers
    }

    /// 订阅编排事件（`lyricsUpgrade` 热替换上抛，D25 #2）。
    /// - Returns: 事件流。
    public func subscribe() -> AsyncStream<LyricsProviderEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<LyricsProviderEvent>.makeStream()
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return stream
    }

    /// 取词（竞速：首个满足 `minMatch` 先用；更高优先级到达热替换）。
    /// - Parameters:
    ///   - track: 曲目。
    ///   - pref: 源偏好。
    /// - Returns: 结果。
    public func lyrics(for track: TrackRef, pref: SourcePreferences) async -> LyricsResult {
        // 缓存命中即回（S2 §4）。
        if let entry = cache?.hit(track: track) {
            return .found(
                data: entry.lyrics,
                source: cachedSource(entry.source),
                quality: entry.quality
            )
        }

        let enabled = adapters.filter { pref.isEnabled($0.id) }
        guard !enabled.isEmpty else { return .missing(reason: .noSourceEnabled) }

        // 并发竞速：每源一个任务。
        var races: [(priority: Int, source: SourceID, task: Task<LyricsResult?, Never>)] = []
        for adapter in enabled {
            let priority = pref.order.firstIndex(of: adapter.id) ?? Int.max
            let breaker = breakers[adapter.id.identifier]
            let latency = pref.lyricsLatencyBySource[adapter.id] ?? 0
            let task = Task<LyricsResult?, Never> { [weak self] in
                guard await breaker?.allows(adapter.id) != false else { return nil }
                return await self?.fetch(
                    from: adapter, track: track,
                    minMatch: pref.minMatch, sourceLatency: latency
                )
            }
            races.append((priority, adapter.id, task))
        }

        // 完成序消费（全部源产出后 finish）。
        let (stream, continuation) = AsyncStream<(Int, SourceID, LyricsResult?)>.makeStream()
        Task {
            await withTaskGroup(of: Void.self) { group in
                for race in races {
                    group.addTask {
                        await continuation.yield((race.priority, race.source, race.task.value))
                    }
                }
            }
            continuation.finish()
        }

        for await (priority, _, value) in stream {
            guard let value, case .found = value else { continue }
            // 首个满足 minMatch 的结果先用；在途更高优先级 → 热替换（D25 #2）。
            let cache = cache
            Task { [weak self] in
                for await (otherPriority, otherSource, other) in stream {
                    guard let other, case let .found(data, _, quality) = other else { continue }
                    if otherPriority < priority {
                        cache?.save(
                            track: track, source: otherSource,
                            raw: data.raw, lyrics: data, quality: quality
                        )
                        await self?.emit(.lyricsUpgrade(other))
                    }
                }
            }
            return value
        }
        return .missing(reason: .notFound)
    }

    /// 预取（S2 §4 `Prepare` 语义：命中即缓存）。
    /// - Parameters:
    ///   - track: 曲目。
    ///   - pref: 源偏好。
    public func prepare(_ track: TrackRef, pref: SourcePreferences) async {
        _ = await lyrics(for: track, pref: pref)
    }

    // MARK: - 私有

    private func removeSubscriber(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    private func emit(_ event: LyricsProviderEvent) {
        for continuation in subscribers.values {
            continuation.yield(event)
        }
    }

    private func cachedSource(_ identifier: String) -> SourceID {
        for adapter in adapters where adapter.id.identifier == identifier {
            return adapter.id
        }
        return .plugin(identifier)
    }

    /// 单源取词：search → T1.19 排序 → fetch → 管线（源延迟 S5）→ 质量标记（D25 #2）。
    private func fetch(
        from adapter: any LyricsSourceAdapter,
        track: TrackRef,
        minMatch: MatchLevel,
        sourceLatency: Int
    ) async -> LyricsResult? {
        let breaker = breakers[adapter.id.identifier]
        do {
            let candidates = try await adapter.search(track)
            for candidate in rankedCandidates(candidates, track: track) {
                guard satisfies(candidate: candidate, track: track, minMatch: minMatch) else { continue }
                do {
                    var data = try await adapter.fetch(candidate)
                    await breaker?.recordSuccess(adapter.id)
                    data = LyricsPipeline.run(
                        data,
                        config: PipelineConfig(sourceDelayMs: sourceLatency)
                    )
                    let quality: LyricsQuality = switch data.syncLevel {
                    case .syllableSynced: .syllableSynced
                    case .lineSynced: .lineSynced
                    case .unsynced: .plain
                    }
                    cache?.save(
                        track: track, source: adapter.id,
                        raw: data.raw, lyrics: data, quality: quality
                    )
                    return .found(data: data, source: adapter.id, quality: quality)
                } catch LyricsSourceError.noResult {
                    continue
                } catch {
                    await breaker?.recordFailure(adapter.id)
                    continue
                }
            }
            return nil
        } catch LyricsSourceError.noResult {
            await breaker?.recordSuccess(adapter.id)
            return nil
        } catch {
            await breaker?.recordFailure(adapter.id)
            return nil
        }
    }

    /// 候选打分排序（T1.19 CandidateRanker，返工后档位 D23/D24）。
    private func rankedCandidates(
        _ candidates: [SourceCandidate],
        track: TrackRef
    ) -> [SourceCandidate] {
        let scored: [(candidate: SourceCandidate, rank: MatchCandidate)] = candidates.map { candidate in
            let name = candidate.track.flatMap { CompareName($0.title, track.title) }
            let artist = candidate.track.flatMap { CompareArtist($0.artists, track.artists) }
            let album = candidate.track.flatMap { $0.album.flatMap { CompareName($0, track.album ?? "") } }
            let duration = CompareDuration(candidate.track?.durationMs, track.durationMs)
            let score = MatchScorer.score(
                MatchScorer.MatchInput(
                    name: name, artist: artist, album: album,
                    albumArtist: nil, duration: duration
                )
            )
            return (
                candidate,
                MatchCandidate(
                    score: score,
                    sourcePriority: 0,
                    offsetMs: 0,
                    supportsSyllable: candidate.quality == .syllableSynced
                )
            )
        }
        return CandidateRanker.rank(scored, by: { $0.rank }).map(\.candidate)
    }

    /// minMatch 达标规则（实现级：曲名档或艺人档 ≥ minMatch）。
    private func satisfies(
        candidate: SourceCandidate,
        track: TrackRef,
        minMatch: MatchLevel
    ) -> Bool {
        guard let candidateTrack = candidate.track else { return true }
        let name = CompareName(candidateTrack.title, track.title) ?? .noMatch
        let artist = CompareArtist(candidateTrack.artists, track.artists) ?? .noMatch
        return name >= minMatch || artist >= minMatch
    }
}

import Foundation
import LyricsCore

/// 重试与限流（S2 §5）。
public enum RetryPolicy: Sendable {
    /// 指数退避序列（毫秒）：1s/2s/4s（最多 3 次）。
    public static let backoffDelaysMs = [1000, 2000, 4000]

    /// 第 n 次重试延迟（1 起）；超出次数返回 `nil`。
    /// - Parameter attempt: 重试序号（1–3）。
    /// - Returns: 延迟毫秒。
    public static func delayMs(attempt: Int) -> Int? {
        guard attempt >= 1, attempt <= backoffDelaysMs.count else { return nil }
        return backoffDelaysMs[attempt - 1]
    }

    /// 429 `Retry-After` 解析（秒 → 毫秒）。
    /// - Parameter response: HTTP 响应。
    /// - Returns: 延迟毫秒；无有效头时为 `nil`。
    public static func retryAfterMs(from response: HTTPURLResponse) -> Int? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = Double(value.trimmingCharacters(in: .whitespaces))
        else {
            return nil
        }
        return Timing.milliseconds(fromSeconds: seconds)
    }
}

/// 源级熔断（S2 §5：连续 5 次失败 → 暂停 60s）。
public actor CircuitBreaker {
    /// 状态。
    private struct State {
        var consecutiveFailures = 0
        var pausedUntil: TimeInterval = -.infinity
    }

    private var states: [String: State] = [:]
    private let failureThreshold: Int
    private let pauseSeconds: TimeInterval
    private let now: @Sendable () -> TimeInterval

    /// 创建熔断器。
    /// - Parameters:
    ///   - failureThreshold: 连续失败阈值（默认 5）。
    ///   - pauseSeconds: 暂停秒数（默认 60）。
    ///   - now: 时钟注入。
    public init(
        failureThreshold: Int = 5,
        pauseSeconds: TimeInterval = 60,
        now: @escaping @Sendable () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.failureThreshold = failureThreshold
        self.pauseSeconds = pauseSeconds
        self.now = now
    }

    /// 是否放行。
    public func allows(_ source: SourceID) -> Bool {
        let state = states[source.identifier]
        return (state?.pausedUntil ?? -.infinity) <= now()
    }

    /// 记录成功（复位）。
    public func recordSuccess(_ source: SourceID) {
        states[source.identifier] = State()
    }

    /// 记录失败；达到阈值时熔断开启。
    /// - Returns: 本次是否触发熔断。
    @discardableResult
    public func recordFailure(_ source: SourceID) -> Bool {
        var state = states[source.identifier] ?? State()
        state.consecutiveFailures += 1
        var tripped = false
        if state.consecutiveFailures >= failureThreshold {
            state.pausedUntil = now() + pauseSeconds
            state.consecutiveFailures = 0
            tripped = true
        }
        states[source.identifier] = state
        return tripped
    }
}

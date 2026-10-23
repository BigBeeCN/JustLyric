import XCTest
@testable import Sources

/// 错误与限流测试（S2 §5）。
final class RetryPolicyTests: XCTestCase {
    /// 指数退避 1s/2s/4s，最多 3 次。
    func testBackoffSequence() {
        XCTAssertEqual(RetryPolicy.delayMs(attempt: 1), 1000)
        XCTAssertEqual(RetryPolicy.delayMs(attempt: 2), 2000)
        XCTAssertEqual(RetryPolicy.delayMs(attempt: 3), 4000)
        XCTAssertNil(RetryPolicy.delayMs(attempt: 4))
        XCTAssertNil(RetryPolicy.delayMs(attempt: 0))
    }

    /// 429 Retry-After 解析。
    func testRetryAfterParsing() throws {
        let url = try XCTUnwrap(URL(string: "https://lrclib.net/api/search"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url, statusCode: 429, httpVersion: "HTTP/1.1",
            headerFields: ["Retry-After": "3"]
        ))
        XCTAssertEqual(RetryPolicy.retryAfterMs(from: response), 3000)
        let without = try XCTUnwrap(HTTPURLResponse(
            url: url, statusCode: 429, httpVersion: "HTTP/1.1", headerFields: nil
        ))
        XCTAssertNil(RetryPolicy.retryAfterMs(from: without))
    }

    /// 熔断：连续 5 败 → 暂停 60s；超窗恢复；成功复位。
    func testCircuitBreaker() async {
        final class Clock: @unchecked Sendable {
            var t: TimeInterval = 0
        }
        let clock = Clock()
        let breaker = CircuitBreaker(failureThreshold: 5, pauseSeconds: 60, now: { clock.t })

        for index in 1 ... 4 {
            let tripped = await breaker.recordFailure(.lrclib)
            XCTAssertFalse(tripped, "第 \(index) 败未触发")
            let allowed = await breaker.allows(.lrclib)
            XCTAssertTrue(allowed)
        }
        let tripped = await breaker.recordFailure(.lrclib)
        XCTAssertTrue(tripped, "第 5 败触发熔断")
        let blocked = await breaker.allows(.lrclib)
        XCTAssertFalse(blocked, "暂停期拒绝")

        clock.t = 61
        let recovered = await breaker.allows(.lrclib)
        XCTAssertTrue(recovered, "60s 后恢复")

        // 成功复位。
        _ = await breaker.recordFailure(.lrclib)
        await breaker.recordSuccess(.lrclib)
        for _ in 1 ... 4 {
            _ = await breaker.recordFailure(.lrclib)
        }
        let notTripped = await breaker.recordFailure(.lrclib)
        XCTAssertTrue(notTripped, "复位后重新计数")
    }
}

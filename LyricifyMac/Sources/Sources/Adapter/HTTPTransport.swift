import Foundation

/// HTTP 传输抽象（适配器可注入 stub，测试确定性）。
public protocol HTTPTransport: Sendable {
    /// 发起请求。
    /// - Parameter request: 请求。
    /// - Returns: 数据与 HTTP 响应。
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// `URLSession` 默认实现。
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    /// 创建传输层。
    /// - Parameter session: URL 会话。
    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LyricsSourceError.transport("非 HTTP 响应")
            }
            return (data, http)
        } catch let error as LyricsSourceError {
            throw error
        } catch {
            throw LyricsSourceError.transport(String(describing: error))
        }
    }
}

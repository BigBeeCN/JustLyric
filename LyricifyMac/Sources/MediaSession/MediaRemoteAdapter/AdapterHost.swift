import Foundation

/// 适配器宿主抽象（S7 D37 #2：perl 弃用对冲——换宿主不换架构）。
///
/// 备选宿主预研位：Widget 扩展（Dynamic Notch 路线）、JXA osascript + ObjC.bindFunction。
public protocol AdapterHost: Sendable {
    /// 启动能力探测（存在→加载→探针应答，D37 #2）。
    func probe() async -> Bool
    /// 启动常驻服务（JSON lines 流式，D37 #4）。
    func start() async -> Bool
    /// 停止。
    func stop()
    /// 最新状态（单查 <100ms——读流缓存，D37 #4）。
    var latestState: [String: Any]? { get }
    /// 状态流。
    var states: AsyncStream<[String: Any]> { get }
}

/// 解析 adapter JSON 行（`{"type":"state","title":…}`）。
enum AdapterPayload {
    /// JSON 行 → 字典。
    static func parse(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else { return nil }
        return dictionary
    }
}

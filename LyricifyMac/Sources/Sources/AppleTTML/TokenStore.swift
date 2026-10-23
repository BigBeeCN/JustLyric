import Foundation
import Security

/// MediaUserToken 存储（[红线-P1]：仅 Keychain `kSecClassGenericPassword`；设置页只显遮罩）。
public final class TokenStore: Sendable {
    private let service: String
    private let account: String

    /// 创建令牌存储。
    /// - Parameters:
    ///   - service: Keychain service。
    ///   - account: Keychain account。
    public init(
        service: String = "com.lyricifymac.mediusertoken",
        account: String = "apple-music"
    ) {
        self.service = service
        self.account = account
    }

    /// 保存令牌（原子覆盖）。
    /// - Parameter token: MediaUserToken。
    public func save(_ token: String) throws {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [kSecValueData as String: Data(token.utf8)]
        let status = SecItemUpdate(attributes as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            let addStatus = SecItemAdd(attributes.merging(update) { $1 } as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw TokenStoreError.keychain(addStatus)
            }
        } else if status != errSecSuccess {
            throw TokenStoreError.keychain(status)
        }
    }

    /// 读取令牌。
    /// - Returns: 令牌；不存在时为 `nil`。
    public func load() -> String? {
        var item: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// 删除令牌。
    public func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.keychain(status)
        }
    }

    /// 遮罩视图（[红线-P1]：设置页只显示遮罩）。
    /// - Returns: 如 `••••ABCD`；未设置时为 `nil`。
    public func maskedToken() -> String? {
        guard let token = load(), !token.isEmpty else { return nil }
        let suffix = token.count >= 4 ? String(token.suffix(4)) : String(repeating: "•", count: 4)
        return "••••\(suffix)"
    }
}

/// Keychain 错误。
public enum TokenStoreError: Error, Sendable, Equatable {
    /// OSStatus 错误。
    case keychain(OSStatus)
}

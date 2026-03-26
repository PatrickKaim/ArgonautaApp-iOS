import Foundation
import Security

nonisolated enum KeychainService {
    static func saveToken(_ token: String) {
        save(key: "meteor-resume-token", value: token)
    }

    static func getToken() -> String? {
        load(key: "meteor-resume-token")
    }

    static func saveUserId(_ userId: String) {
        save(key: "meteor-user-id", value: userId)
    }

    static func getUserId() -> String? {
        load(key: "meteor-user-id")
    }

    static func clearAll() {
        delete(key: "meteor-resume-token")
        delete(key: "meteor-user-id")
    }

    private static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "nl.argonauta.app",
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "nl.argonauta.app",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "nl.argonauta.app",
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}


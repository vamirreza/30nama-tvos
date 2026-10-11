import Foundation
import Security

/// The session token lives in the keychain, not in UserDefaults.
enum Keychain {
    private static let service = "com.vamirreza.sinama.tv"

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Returns false when the keychain refused the write (for example an unsigned build).
    @discardableResult
    static func set(_ key: String, _ value: String?) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(base as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return true }
        var add = base
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess { NSLog("[keychain] add failed: \(status)") }
        return status == errSecSuccess
    }
}

enum SessionStore {
    private static let key = "30nama.v2.token"
    private static let fallbackKey = "30nama.v2.token.fallback"
    /// Survives a keychain that rejects writes, for the life of the process at least.
    private static var memory: String?

    static var token: String? {
        get { memory ?? Keychain.get(key) ?? UserDefaults.standard.string(forKey: fallbackKey) }
        set {
            memory = newValue
            // The keychain is the home of the token; UserDefaults only holds it if the keychain refuses.
            if Keychain.set(key, newValue) {
                UserDefaults.standard.removeObject(forKey: fallbackKey)
            } else if let newValue {
                UserDefaults.standard.set(newValue, forKey: fallbackKey)
            }
        }
    }
}

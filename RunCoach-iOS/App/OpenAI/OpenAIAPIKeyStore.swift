import Foundation
import Security

/// Guarda/lee la API key de OpenAI en el Keychain de iOS — nunca en
/// `UserDefaults`, nunca en el código fuente, nunca en Git. La única
/// forma de que exista una key acá es que Vicente la pegue a mano en
/// `SettingsView`.
enum OpenAIAPIKeyStore {
    private static let service = "com.vicente.runcoach.openai"
    private static let account = "api-key"

    static var currentKey: String? {
        read()
    }

    static func save(_ key: String) {
        delete()
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Solo accesible con el dispositivo desbloqueado, y nunca se
            // incluye en backups a otros dispositivos.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

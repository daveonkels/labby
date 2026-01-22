import Foundation
import Security

/// Manages secure storage of credentials in the iOS Keychain
enum KeychainManager {
    private static let service = "com.labby.homepage-auth"

    /// Saves a password for a connection ID
    /// - Parameters:
    ///   - password: The password to store
    ///   - connectionId: The UUID of the HomepageConnection
    /// - Returns: True if save was successful
    @discardableResult
    static func savePassword(_ password: String, for connectionId: UUID) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }

        let account = connectionId.uuidString

        // Delete any existing password first
        deletePassword(for: connectionId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves the password for a connection ID
    /// - Parameter connectionId: The UUID of the HomepageConnection
    /// - Returns: The stored password, or nil if not found
    static func getPassword(for connectionId: UUID) -> String? {
        let account = connectionId.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }

    /// Deletes the password for a connection ID
    /// - Parameter connectionId: The UUID of the HomepageConnection
    /// - Returns: True if deletion was successful or item didn't exist
    @discardableResult
    static func deletePassword(for connectionId: UUID) -> Bool {
        let account = connectionId.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Creates a Basic Auth header value from username and password
    /// - Parameters:
    ///   - username: The username
    ///   - password: The password
    /// - Returns: The Base64-encoded "username:password" string for Authorization header
    static func basicAuthHeaderValue(username: String, password: String) -> String {
        let credentials = "\(username):\(password)"
        let data = credentials.data(using: .utf8)!
        return "Basic \(data.base64EncodedString())"
    }
}

import Foundation
import Security

// MARK: - KeychainService

/// A lightweight wrapper around the iOS Security framework for storing sensitive
/// string values (e.g. the Claude API key) in the device Keychain.
///
/// All items are stored as `kSecClassGenericPassword` with
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` so that data is protected
/// at rest and never migrated to another device via backup or iCloud.
final class KeychainService {

    // MARK: - Service identifier

    /// The service name used to namespace all Keychain items for this app.
    private let service: String

    // MARK: - Initialisation

    /// - Parameter service: A reverse-DNS string identifying the app, e.g. `"com.example.FitnessTracker"`.
    ///   Defaults to the main bundle identifier, falling back to a fixed string.
    init(service: String = Bundle.main.bundleIdentifier ?? "com.fitnessTracker.app") {
        self.service = service
    }

    // MARK: - Public API

    /// Saves a string value for the given key.
    ///
    /// If an entry already exists for the key it is updated in place; otherwise a
    /// new item is created.
    ///
    /// - Parameters:
    ///   - value: The string to store.
    ///   - key: A unique identifier for the item, e.g. `"claudeAPIKey"`.
    /// - Throws: `KeychainError.saveFailed` with the underlying OSStatus on failure.
    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Try updating an existing item first.
        let query = baseQuery(forKey: key)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // No existing item — insert a new one.
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(status: addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.saveFailed(status: updateStatus)
        }
    }

    /// Reads the string value stored for the given key.
    ///
    /// - Parameter key: The key used when the item was saved.
    /// - Returns: The stored string, or `nil` if no item exists for the key.
    /// - Throws: `KeychainError.readFailed` if the Keychain query returns an unexpected error.
    func read(forKey key: String) throws -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard
                let data = result as? Data,
                let string = String(data: data, encoding: .utf8)
            else {
                throw KeychainError.decodingFailed
            }
            return string

        case errSecItemNotFound:
            return nil

        default:
            throw KeychainError.readFailed(status: status)
        }
    }

    /// Deletes the Keychain item for the given key.
    ///
    /// Succeeds silently if no item exists for the key.
    ///
    /// - Parameter key: The key used when the item was saved.
    /// - Throws: `KeychainError.deleteFailed` if deletion returns an unexpected error.
    func delete(forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    // MARK: - Convenience accessors

    /// Stores the Claude API key in the Keychain.
    func saveAPIKey(_ apiKey: String) throws {
        try save(apiKey, forKey: KeychainKey.claudeAPIKey)
    }

    /// Retrieves the Claude API key from the Keychain.
    func apiKey() throws -> String? {
        try read(forKey: KeychainKey.claudeAPIKey)
    }

    /// Deletes the Claude API key from the Keychain.
    func deleteAPIKey() throws {
        try delete(forKey: KeychainKey.claudeAPIKey)
    }

    // MARK: - Private helpers

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}

// MARK: - Well-known keys

enum KeychainKey {
    static let claudeAPIKey = "claudeAPIKey"
    static let userAuthToken = "userAuthToken"
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case saveFailed(status: OSStatus)
    case readFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode value as UTF-8 data."
        case .decodingFailed:
            return "Failed to decode stored Keychain data as a UTF-8 string."
        case .saveFailed(let status):
            return "Keychain save failed with status: \(status)."
        case .readFailed(let status):
            return "Keychain read failed with status: \(status)."
        case .deleteFailed(let status):
            return "Keychain delete failed with status: \(status)."
        }
    }
}

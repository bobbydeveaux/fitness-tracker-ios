import Foundation

// MARK: - Stub (fully implemented in task-ios-fitness-tracker-app-feat-foundation-4)

/// Wraps the Security framework (`kSecClassGenericPassword`) for storing
/// sensitive values such as the Claude API key in the iOS Keychain.
///
/// The full implementation using `SecItemAdd`, `SecItemCopyMatching`, and
/// `SecItemDelete` is added in task-ios-fitness-tracker-app-feat-foundation-4.
final class KeychainService {

    enum KeychainError: Error {
        case itemNotFound
        case encodingFailed
        case unhandledError(OSStatus)
    }

    // MARK: - Init

    init() {}

    // MARK: - API (stub bodies replaced in foundation-4)

    /// Stores a string value for the given key using `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
    func save(_ value: String, for key: String) throws {
        // Implementation added in task-ios-fitness-tracker-app-feat-foundation-4
    }

    /// Retrieves the string value for the given key.
    func read(for key: String) throws -> String {
        throw KeychainError.itemNotFound
    }

    /// Removes the value for the given key from the Keychain.
    func delete(for key: String) throws {
        // Implementation added in task-ios-fitness-tracker-app-feat-foundation-4
    }
}

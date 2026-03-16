import XCTest
@testable import FitnessTracker

// MARK: - KeychainServiceTests

final class KeychainServiceTests: XCTestCase {

    // MARK: - Properties

    /// Use a test-specific service namespace so tests never touch production Keychain items.
    private let testService = "com.fitnessTracker.tests"
    private var sut: KeychainService!

    // MARK: - Test keys

    private let testKey = "testKey"
    private let testValue = "s3cr3t-t0k3n"
    private let updatedValue = "updated-t0k3n"

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        sut = KeychainService(service: testService)
        // Clean up any leftovers from a previous run.
        try? sut.delete(forKey: testKey)
    }

    override func tearDown() {
        try? sut.delete(forKey: testKey)
        sut = nil
        super.tearDown()
    }

    // MARK: - Save

    /// Saving a value must not throw.
    func test_save_doesNotThrow() {
        XCTAssertNoThrow(try sut.save(testValue, forKey: testKey))
    }

    // MARK: - Read

    /// Reading a key that was just saved should return the original value.
    func test_read_afterSave_returnsStoredValue() throws {
        try sut.save(testValue, forKey: testKey)
        let result = try sut.read(forKey: testKey)
        XCTAssertEqual(result, testValue)
    }

    /// Reading a key that has never been saved should return nil.
    func test_read_forMissingKey_returnsNil() throws {
        let result = try sut.read(forKey: "nonexistent-key-\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    // MARK: - Update

    /// Saving a new value for an existing key must overwrite the previous value.
    func test_save_overwrites_existingValue() throws {
        try sut.save(testValue, forKey: testKey)
        try sut.save(updatedValue, forKey: testKey)
        let result = try sut.read(forKey: testKey)
        XCTAssertEqual(result, updatedValue, "Second save should overwrite first value")
    }

    // MARK: - Delete

    /// Deleting a saved key should make subsequent reads return nil.
    func test_delete_removesValue() throws {
        try sut.save(testValue, forKey: testKey)
        try sut.delete(forKey: testKey)
        let result = try sut.read(forKey: testKey)
        XCTAssertNil(result, "After deletion, read should return nil")
    }

    /// Deleting a key that does not exist should succeed silently (no throw).
    func test_delete_forMissingKey_doesNotThrow() {
        XCTAssertNoThrow(try sut.delete(forKey: "never-saved-\(UUID().uuidString)"))
    }

    // MARK: - Round-trip

    /// Full save → read → delete → read cycle.
    func test_fullRoundTrip() throws {
        // Save
        try sut.save(testValue, forKey: testKey)

        // Read — should match
        let readBack = try sut.read(forKey: testKey)
        XCTAssertEqual(readBack, testValue)

        // Delete
        try sut.delete(forKey: testKey)

        // Read after delete — should be nil
        let afterDelete = try sut.read(forKey: testKey)
        XCTAssertNil(afterDelete)
    }

    // MARK: - Special characters

    /// Values containing special characters should round-trip correctly.
    func test_save_read_specialCharacters() throws {
        let special = "P@$$w0rd!#%^&*()_+{}|:\"<>?"
        try sut.save(special, forKey: testKey)
        let result = try sut.read(forKey: testKey)
        XCTAssertEqual(result, special)
    }

    // MARK: - Convenience API — Claude API key

    /// Convenience saveAPIKey / apiKey / deleteAPIKey methods work as expected.
    func test_apiKeyConvenience_roundTrip() throws {
        let apiKey = "sk-ant-test1234567890"
        let apiKeyKeychainKey = KeychainKey.claudeAPIKey

        // Ensure clean state
        try? sut.delete(forKey: apiKeyKeychainKey)

        try sut.saveAPIKey(apiKey)
        let retrieved = try sut.apiKey()
        XCTAssertEqual(retrieved, apiKey)

        try sut.deleteAPIKey()
        let afterDelete = try sut.apiKey()
        XCTAssertNil(afterDelete)
    }

    // MARK: - Multiple keys

    /// Items stored under different keys must not interfere with each other.
    func test_multipleKeys_areIndependent() throws {
        let keyA = "keyA-\(UUID().uuidString)"
        let keyB = "keyB-\(UUID().uuidString)"
        defer {
            try? sut.delete(forKey: keyA)
            try? sut.delete(forKey: keyB)
        }

        try sut.save("valueA", forKey: keyA)
        try sut.save("valueB", forKey: keyB)

        XCTAssertEqual(try sut.read(forKey: keyA), "valueA")
        XCTAssertEqual(try sut.read(forKey: keyB), "valueB")

        try sut.delete(forKey: keyA)

        XCTAssertNil(try sut.read(forKey: keyA))
        XCTAssertEqual(try sut.read(forKey: keyB), "valueB")
    }
}

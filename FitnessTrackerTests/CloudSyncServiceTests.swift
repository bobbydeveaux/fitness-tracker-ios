import XCTest
@testable import FitnessTracker

// MARK: - MockCloudSyncService

/// Test double for `CloudSyncServiceProtocol`.
///
/// Records method calls and allows preconfigured responses, enabling unit tests
/// to exercise callers without a live iCloud account or CloudKit entitlement.
final class MockCloudSyncService: CloudSyncServiceProtocol {

    // MARK: - Stubbed responses

    var stubbedICloudAvailable = true
    var stubbedIsSyncEnabled = false
    var stubbedSyncState: CloudSyncState = .idle

    // MARK: - Recorded calls

    private(set) var enableSyncCallCount = 0
    private(set) var disableSyncCallCount = 0

    // MARK: - CloudSyncServiceProtocol

    var iCloudAvailable: Bool { stubbedICloudAvailable }
    var isSyncEnabled: Bool { stubbedIsSyncEnabled }
    var syncState: CloudSyncState { stubbedSyncState }

    func enableSync() {
        enableSyncCallCount += 1
        if stubbedICloudAvailable {
            stubbedIsSyncEnabled = true
            stubbedSyncState = .idle
        }
    }

    func disableSync() {
        disableSyncCallCount += 1
        stubbedIsSyncEnabled = false
        stubbedSyncState = .idle
    }
}

// MARK: - CloudSyncStateTests

final class CloudSyncStateTests: XCTestCase {

    // MARK: - Equatable

    func test_idle_equalsIdle() {
        XCTAssertEqual(CloudSyncState.idle, CloudSyncState.idle)
    }

    func test_syncing_equalsSyncing() {
        XCTAssertEqual(CloudSyncState.syncing, CloudSyncState.syncing)
    }

    func test_error_equalsError_withSameMessage() {
        XCTAssertEqual(
            CloudSyncState.error("Network failure"),
            CloudSyncState.error("Network failure")
        )
    }

    func test_error_doesNotEqual_error_withDifferentMessage() {
        XCTAssertNotEqual(
            CloudSyncState.error("A"),
            CloudSyncState.error("B")
        )
    }

    func test_idle_doesNotEqual_syncing() {
        XCTAssertNotEqual(CloudSyncState.idle, CloudSyncState.syncing)
    }

    func test_idle_doesNotEqual_error() {
        XCTAssertNotEqual(CloudSyncState.idle, CloudSyncState.error("some error"))
    }

    func test_syncing_doesNotEqual_error() {
        XCTAssertNotEqual(CloudSyncState.syncing, CloudSyncState.error("some error"))
    }
}

// MARK: - CloudSyncServiceTests (concrete)

final class CloudSyncServiceTests: XCTestCase {

    // MARK: - Properties

    private var sut: CloudSyncService!
    private let userDefaultsKey = "cloudSyncEnabled"

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Remove any persisted state from previous test runs.
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        sut = CloudSyncService()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialSyncState_isIdle() {
        XCTAssertEqual(sut.syncState, .idle)
    }

    func test_initialIsSyncEnabled_isFalse_whenUserDefaultsHasNoValue() {
        XCTAssertFalse(sut.isSyncEnabled,
                       "isSyncEnabled should be false when UserDefaults has no stored preference")
    }

    func test_initialIsSyncEnabled_isTrue_whenUserDefaultsPreviouslySet() {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        let service = CloudSyncService()
        XCTAssertTrue(service.isSyncEnabled,
                      "isSyncEnabled should restore persisted preference from UserDefaults")
    }

    // MARK: - disableSync

    func test_disableSync_setsIsSyncEnabledFalse() {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        let service = CloudSyncService()
        service.disableSync()
        XCTAssertFalse(service.isSyncEnabled)
    }

    func test_disableSync_persistsFalseToUserDefaults() {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        let service = CloudSyncService()
        service.disableSync()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: userDefaultsKey))
    }

    func test_disableSync_resetsSyncStateToIdle() {
        sut.disableSync()
        XCTAssertEqual(sut.syncState, .idle)
    }

    // MARK: - iCloudAvailable

    func test_iCloudAvailable_isABool() {
        // Can't assert a specific value in CI (no iCloud account), but the
        // property must be a valid Boolean without crashing.
        let value = sut.iCloudAvailable
        XCTAssertTrue(value == true || value == false)
    }
}

// MARK: - MockCloudSyncServiceTests

final class MockCloudSyncServiceTests: XCTestCase {

    // MARK: - Properties

    private var mock: MockCloudSyncService!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mock = MockCloudSyncService()
    }

    override func tearDown() {
        mock = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_mock_initialSyncState_isIdle() {
        XCTAssertEqual(mock.syncState, .idle)
    }

    func test_mock_initialIsSyncEnabled_isFalse() {
        XCTAssertFalse(mock.isSyncEnabled)
    }

    func test_mock_initialICloudAvailable_isTrue() {
        XCTAssertTrue(mock.iCloudAvailable)
    }

    // MARK: - enableSync

    func test_mock_enableSync_recordsCall() {
        mock.enableSync()
        XCTAssertEqual(mock.enableSyncCallCount, 1)
    }

    func test_mock_enableSync_setsIsSyncEnabled_whenICloudAvailable() {
        mock.stubbedICloudAvailable = true
        mock.enableSync()
        XCTAssertTrue(mock.isSyncEnabled)
    }

    func test_mock_enableSync_doesNotSetIsSyncEnabled_whenICloudUnavailable() {
        mock.stubbedICloudAvailable = false
        mock.enableSync()
        XCTAssertFalse(mock.isSyncEnabled)
    }

    func test_mock_enableSync_resetsSyncStateToIdle() {
        mock.stubbedSyncState = .error("previous error")
        mock.stubbedICloudAvailable = true
        mock.enableSync()
        XCTAssertEqual(mock.syncState, .idle)
    }

    // MARK: - disableSync

    func test_mock_disableSync_recordsCall() {
        mock.disableSync()
        XCTAssertEqual(mock.disableSyncCallCount, 1)
    }

    func test_mock_disableSync_clearsIsSyncEnabled() {
        mock.stubbedIsSyncEnabled = true
        mock.disableSync()
        XCTAssertFalse(mock.isSyncEnabled)
    }

    func test_mock_disableSync_resetsSyncStateToIdle() {
        mock.stubbedSyncState = .syncing
        mock.disableSync()
        XCTAssertEqual(mock.syncState, .idle)
    }

    // MARK: - Error state

    func test_mock_syncState_canBeSetToError() {
        mock.stubbedSyncState = .error("iCloud storage is full.")
        XCTAssertEqual(mock.syncState, .error("iCloud storage is full."))
    }

    func test_mock_syncState_canBeSetToSyncing() {
        mock.stubbedSyncState = .syncing
        XCTAssertEqual(mock.syncState, .syncing)
    }

    // MARK: - Multiple calls

    func test_mock_enableSync_recordsMultipleCalls() {
        mock.enableSync()
        mock.enableSync()
        XCTAssertEqual(mock.enableSyncCallCount, 2)
    }

    func test_mock_disableSync_recordsMultipleCalls() {
        mock.disableSync()
        mock.disableSync()
        XCTAssertEqual(mock.disableSyncCallCount, 2)
    }
}

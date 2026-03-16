import XCTest
import UserNotifications
@testable import FitnessTracker

// MARK: - MockNotificationCenter

/// Test double for `NotificationCenterProtocol`.
///
/// Captures all calls and arguments so tests can assert exact scheduling
/// behaviour without interacting with the real `UNUserNotificationCenter`.
private final class MockNotificationCenter: NotificationCenterProtocol {

    // MARK: - Stubs

    /// Pre-configure to simulate the system granting or denying permission.
    var stubbedAuthorizationGranted = true

    /// Pre-configure to simulate `add(_:)` throwing an error.
    var stubbedAddError: Error?

    /// Populate to simulate pre-existing pending notification requests.
    var stubbedPendingRequests: [UNNotificationRequest] = []

    // MARK: - Recorded calls

    private(set) var requestAuthorizationCallCount = 0
    private(set) var requestedOptions: UNAuthorizationOptions?
    private(set) var removedIdentifiers: [String] = []
    private(set) var addedRequests: [UNNotificationRequest] = []

    // MARK: - NotificationCenterProtocol

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        requestedOptions = options
        return stubbedAuthorizationGranted
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        stubbedPendingRequests
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        // Also remove them from the stub so subsequent reads reflect the removal.
        stubbedPendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let error = stubbedAddError { throw error }
        addedRequests.append(request)
    }
}

// MARK: - MockNotificationScheduler

/// Protocol-level test double used to verify that higher-level components
/// (e.g. a SettingsViewModel) call the scheduler correctly.
private final class MockNotificationScheduler: NotificationSchedulerProtocol {

    // MARK: - Recorded calls

    private(set) var requestPermissionCallCount = 0
    private(set) var scheduleCallArguments: [(days: [Int], time: DateComponents)] = []
    private(set) var cancelAllCallCount = 0

    // MARK: - Stubs

    var stubbedAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - NotificationSchedulerProtocol

    var authorizationStatus: UNAuthorizationStatus { stubbedAuthorizationStatus }

    func requestPermission() async {
        requestPermissionCallCount += 1
    }

    func scheduleReminders(days: [Int], time: DateComponents) async {
        scheduleCallArguments.append((days: days, time: time))
    }

    func cancelAll() async {
        cancelAllCallCount += 1
    }
}

// MARK: - Helpers

/// Builds a minimal `UNNotificationRequest` using a `UNCalendarNotificationTrigger`
/// for the given identifier and weekday.
private func makeRequest(identifier: String, weekday: Int) -> UNNotificationRequest {
    var components = DateComponents()
    components.weekday = weekday
    components.hour = 8
    components.minute = 0
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    let content = UNMutableNotificationContent()
    content.title = "Reminder"
    return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
}

// MARK: - NotificationSchedulerTests

final class NotificationSchedulerTests: XCTestCase {

    // MARK: - Properties

    private var mockCenter: MockNotificationCenter!
    private var sut: NotificationScheduler!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mockCenter = MockNotificationCenter()
        sut = NotificationScheduler(center: mockCenter)
    }

    override func tearDown() {
        sut = nil
        mockCenter = nil
        super.tearDown()
    }

    // MARK: - Singleton

    func test_shared_returnsSameInstance() {
        let a = NotificationScheduler.shared
        let b = NotificationScheduler.shared
        XCTAssertTrue(a === b, "shared must always return the same singleton instance")
    }

    // MARK: - identifierPrefix

    func test_identifierPrefix_hasExpectedValue() {
        XCTAssertEqual(NotificationScheduler.identifierPrefix, "fitness-reminder-")
    }

    // MARK: - Initial state

    func test_initialAuthorizationStatus_isNotDetermined() {
        XCTAssertEqual(sut.authorizationStatus, .notDetermined)
    }

    // MARK: - requestPermission

    func test_requestPermission_callsCenter() async {
        await sut.requestPermission()
        XCTAssertEqual(mockCenter.requestAuthorizationCallCount, 1)
    }

    func test_requestPermission_requestsAlertSoundBadge() async {
        await sut.requestPermission()
        let options = try XCTUnwrap(mockCenter.requestedOptions)
        XCTAssertTrue(options.contains(.alert))
        XCTAssertTrue(options.contains(.sound))
        XCTAssertTrue(options.contains(.badge))
    }

    func test_requestPermission_setsAuthorizedWhenGranted() async {
        mockCenter.stubbedAuthorizationGranted = true
        await sut.requestPermission()
        XCTAssertEqual(sut.authorizationStatus, .authorized)
    }

    func test_requestPermission_setsDeniedWhenNotGranted() async {
        mockCenter.stubbedAuthorizationGranted = false
        await sut.requestPermission()
        XCTAssertEqual(sut.authorizationStatus, .denied)
    }

    func test_requestPermission_setsDeniedWhenCenterThrows() async {
        struct AuthError: Error {}
        // Simulate system error by replacing the center with a throwing version.
        final class ThrowingCenter: NotificationCenterProtocol {
            func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
                throw AuthError()
            }
            func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
            func removePendingNotificationRequests(withIdentifiers: [String]) {}
            func add(_ request: UNNotificationRequest) async throws {}
        }
        let scheduler = NotificationScheduler(center: ThrowingCenter())
        await scheduler.requestPermission()
        XCTAssertEqual(scheduler.authorizationStatus, .denied)
    }

    // MARK: - scheduleReminders

    func test_scheduleReminders_addsOneRequestPerDay() async {
        let days = [2, 4, 6]
        let time = DateComponents(hour: 7, minute: 30)
        await sut.scheduleReminders(days: days, time: time)
        XCTAssertEqual(mockCenter.addedRequests.count, 3)
    }

    func test_scheduleReminders_usesCorrectIdentifierPrefix() async {
        await sut.scheduleReminders(days: [3], time: DateComponents(hour: 9, minute: 0))
        let identifier = try XCTUnwrap(mockCenter.addedRequests.first?.identifier)
        XCTAssertTrue(identifier.hasPrefix(NotificationScheduler.identifierPrefix),
                      "Request identifier must start with '\(NotificationScheduler.identifierPrefix)'")
    }

    func test_scheduleReminders_identifierEncodesWeekday() async {
        await sut.scheduleReminders(days: [5], time: DateComponents(hour: 6, minute: 0))
        let identifier = try XCTUnwrap(mockCenter.addedRequests.first?.identifier)
        XCTAssertEqual(identifier, "\(NotificationScheduler.identifierPrefix)5")
    }

    func test_scheduleReminders_triggerMatchesRequestedTime() async {
        let time = DateComponents(hour: 8, minute: 15)
        await sut.scheduleReminders(days: [2], time: time)
        let request = try XCTUnwrap(mockCenter.addedRequests.first)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.hour, 8)
        XCTAssertEqual(trigger.dateComponents.minute, 15)
    }

    func test_scheduleReminders_triggerEncodesWeekday() async {
        await sut.scheduleReminders(days: [4], time: DateComponents(hour: 7, minute: 0))
        let request = try XCTUnwrap(mockCenter.addedRequests.first)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.weekday, 4)
    }

    func test_scheduleReminders_triggerRepeats() async {
        await sut.scheduleReminders(days: [2], time: DateComponents(hour: 7, minute: 0))
        let request = try XCTUnwrap(mockCenter.addedRequests.first)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats, "Weekly reminders must repeat")
    }

    func test_scheduleReminders_removesExistingFitnessRemindersFirst() async {
        // Pre-populate the center with existing fitness-reminder requests.
        let existing = [
            makeRequest(identifier: "fitness-reminder-2", weekday: 2),
            makeRequest(identifier: "fitness-reminder-4", weekday: 4)
        ]
        mockCenter.stubbedPendingRequests = existing

        await sut.scheduleReminders(days: [3], time: DateComponents(hour: 7, minute: 0))

        XCTAssertTrue(
            mockCenter.removedIdentifiers.contains("fitness-reminder-2"),
            "Old Monday reminder must be removed"
        )
        XCTAssertTrue(
            mockCenter.removedIdentifiers.contains("fitness-reminder-4"),
            "Old Wednesday reminder must be removed"
        )
    }

    func test_scheduleReminders_doesNotRemoveNonFitnessNotifications() async {
        let other = makeRequest(identifier: "meal-reminder-1", weekday: 2)
        mockCenter.stubbedPendingRequests = [other]

        await sut.scheduleReminders(days: [2], time: DateComponents(hour: 8, minute: 0))

        XCTAssertFalse(
            mockCenter.removedIdentifiers.contains("meal-reminder-1"),
            "Non-fitness notifications must not be touched"
        )
    }

    func test_scheduleReminders_emptyDays_schedulesNothing() async {
        await sut.scheduleReminders(days: [], time: DateComponents(hour: 8, minute: 0))
        XCTAssertEqual(mockCenter.addedRequests.count, 0)
    }

    func test_scheduleReminders_calledTwice_replacesReminders() async {
        let time = DateComponents(hour: 7, minute: 0)
        await sut.scheduleReminders(days: [2, 4], time: time)
        // Second call should replace the first set.
        await sut.scheduleReminders(days: [6], time: time)
        // Only the single day from the second call should remain.
        XCTAssertEqual(mockCenter.addedRequests.count, 3,
                       "2 from first call + 1 from second call = 3 total add() calls")
        // The first two should have been removed before the second scheduling.
        XCTAssertTrue(mockCenter.removedIdentifiers.contains("fitness-reminder-2"))
        XCTAssertTrue(mockCenter.removedIdentifiers.contains("fitness-reminder-4"))
    }

    // MARK: - cancelAll

    func test_cancelAll_removesFitnessReminders() async {
        mockCenter.stubbedPendingRequests = [
            makeRequest(identifier: "fitness-reminder-2", weekday: 2),
            makeRequest(identifier: "fitness-reminder-5", weekday: 5)
        ]

        await sut.cancelAll()

        XCTAssertTrue(mockCenter.removedIdentifiers.contains("fitness-reminder-2"))
        XCTAssertTrue(mockCenter.removedIdentifiers.contains("fitness-reminder-5"))
    }

    func test_cancelAll_leavesNonFitnessNotificationsUntouched() async {
        mockCenter.stubbedPendingRequests = [
            makeRequest(identifier: "fitness-reminder-3", weekday: 3),
            makeRequest(identifier: "meal-reminder-1", weekday: 1)
        ]

        await sut.cancelAll()

        XCTAssertFalse(
            mockCenter.removedIdentifiers.contains("meal-reminder-1"),
            "cancelAll() must only remove fitness-reminder-* notifications"
        )
    }

    func test_cancelAll_whenNoPendingReminders_doesNotCrash() async {
        mockCenter.stubbedPendingRequests = []
        await sut.cancelAll()
        // No assertion needed — test passes if no crash occurs.
    }
}

// MARK: - MockNotificationSchedulerTests

/// Verifies that `MockNotificationScheduler` correctly records calls so it can
/// serve as a reliable test double for components that depend on
/// `NotificationSchedulerProtocol`.
final class MockNotificationSchedulerTests: XCTestCase {

    private var mock: MockNotificationScheduler!

    override func setUp() {
        super.setUp()
        mock = MockNotificationScheduler()
    }

    override func tearDown() {
        mock = nil
        super.tearDown()
    }

    func test_mock_initialStatus_isNotDetermined() {
        XCTAssertEqual(mock.authorizationStatus, .notDetermined)
    }

    func test_mock_requestPermission_recordsCall() async {
        XCTAssertEqual(mock.requestPermissionCallCount, 0)
        await mock.requestPermission()
        XCTAssertEqual(mock.requestPermissionCallCount, 1)
    }

    func test_mock_scheduleReminders_recordsArguments() async {
        let days = [2, 4]
        let time = DateComponents(hour: 7, minute: 0)
        await mock.scheduleReminders(days: days, time: time)
        XCTAssertEqual(mock.scheduleCallArguments.count, 1)
        XCTAssertEqual(mock.scheduleCallArguments[0].days, days)
        XCTAssertEqual(mock.scheduleCallArguments[0].time.hour, 7)
    }

    func test_mock_cancelAll_recordsCall() async {
        XCTAssertEqual(mock.cancelAllCallCount, 0)
        await mock.cancelAll()
        XCTAssertEqual(mock.cancelAllCallCount, 1)
    }

    func test_mock_stubbedStatus_isReflected() {
        mock.stubbedAuthorizationStatus = .authorized
        XCTAssertEqual(mock.authorizationStatus, .authorized)
    }
}

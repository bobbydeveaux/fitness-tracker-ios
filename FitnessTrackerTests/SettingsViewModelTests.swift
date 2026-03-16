import XCTest
@testable import FitnessTracker

// MARK: - MockNotificationScheduler

final class MockNotificationScheduler: NotificationSchedulerProtocol, @unchecked Sendable {
    private(set) var requestPermissionCallCount = 0
    private(set) var scheduleCallCount = 0
    private(set) var cancelAllCallCount = 0

    private(set) var lastScheduledDays: [Int] = []
    private(set) var lastScheduledTime: DateComponents = DateComponents()

    /// Pre-configure to simulate the system granting or denying permission.
    var permissionGranted: Bool = true

    // MARK: - NotificationSchedulerProtocol

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    func requestPermission() async {
        requestPermissionCallCount += 1
        authorizationStatus = permissionGranted ? .authorized : .denied
    }

    func scheduleReminders(days: [Int], time: DateComponents) async {
        scheduleCallCount += 1
        lastScheduledDays = days
        lastScheduledTime = time
    }

    func cancelAll() async {
        cancelAllCallCount += 1
    }
}

// MARK: - MockCloudSyncService

final class MockCloudSyncService: CloudSyncServiceProtocol, @unchecked Sendable {
    private(set) var checkAvailabilityCallCount = 0
    var syncState: CloudSyncState = .synced
    var iCloudAvailable: Bool = true
    var isSyncEnabled: Bool = false

    func checkAvailability() async {
        checkAvailabilityCallCount += 1
    }

    func enableSync() {}
    func disableSync() {}
}

// MARK: - SettingsViewModelTests

@MainActor
final class SettingsViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSuite(named name: String = #function) -> UserDefaults {
        let suite = UserDefaults(suiteName: "test.\(name).\(UUID().uuidString)")!
        return suite
    }

    private func makeViewModel(
        scheduler: MockNotificationScheduler = MockNotificationScheduler(),
        cloud: MockCloudSyncService = MockCloudSyncService(),
        defaults: UserDefaults? = nil
    ) -> (SettingsViewModel, MockNotificationScheduler, MockCloudSyncService) {
        let d = defaults ?? makeSuite()
        let vm = SettingsViewModel(
            notificationScheduler: scheduler,
            cloudSyncService: cloud,
            defaults: d
        )
        return (vm, scheduler, cloud)
    }

    // MARK: - Default State

    func testDefaultAppearanceMode_isDark() {
        let (vm, _, _) = makeViewModel()
        XCTAssertEqual(vm.appearanceMode, .dark)
    }

    func testDefaultNotificationsEnabled_isFalse() {
        let (vm, _, _) = makeViewModel()
        XCTAssertFalse(vm.notificationsEnabled)
    }

    func testDefaultReminderDays_containsMondayWednesdayFriday() {
        let (vm, _, _) = makeViewModel()
        XCTAssertTrue(vm.reminderDays.contains(.monday))
        XCTAssertTrue(vm.reminderDays.contains(.wednesday))
        XCTAssertTrue(vm.reminderDays.contains(.friday))
    }

    func testDefaultReminderTime_isEightAM() {
        let (vm, _, _) = makeViewModel()
        XCTAssertEqual(vm.reminderTime.hour, 8)
        XCTAssertEqual(vm.reminderTime.minute, 0)
    }

    // MARK: - Appearance Persistence

    func testAppearanceMode_persistsAfterChange() {
        let suite = makeSuite()
        let (vm, _, _) = makeViewModel(defaults: suite)

        vm.appearanceMode = .light

        // New view-model reading same suite should restore .light
        let (vm2, _, _) = makeViewModel(defaults: suite)
        XCTAssertEqual(vm2.appearanceMode, .light)
    }

    func testAppearanceMode_systemModeRoundTrips() {
        let suite = makeSuite()
        let (vm, _, _) = makeViewModel(defaults: suite)

        vm.appearanceMode = .system

        let (vm2, _, _) = makeViewModel(defaults: suite)
        XCTAssertEqual(vm2.appearanceMode, .system)
    }

    // MARK: - Notification Scheduling

    func testEnablingNotifications_requestsPermission() async {
        let scheduler = MockNotificationScheduler()
        let (vm, _, _) = makeViewModel(scheduler: scheduler)

        vm.notificationsEnabled = true

        // Allow the async Task started by didSet to complete.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(scheduler.requestPermissionCallCount, 1)
    }

    func testEnablingNotifications_schedulesRemindersWhenGranted() async {
        let scheduler = MockNotificationScheduler()
        scheduler.permissionGranted = true
        let (vm, _, _) = makeViewModel(scheduler: scheduler)

        vm.notificationsEnabled = true

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(scheduler.scheduleCallCount, 1)
    }

    func testEnablingNotifications_doesNotScheduleWhenDenied() async {
        let scheduler = MockNotificationScheduler()
        scheduler.permissionGranted = false
        let (vm, _, _) = makeViewModel(scheduler: scheduler)

        vm.notificationsEnabled = true

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(scheduler.scheduleCallCount, 0)
    }

    func testDisablingNotifications_cancelsAll() async {
        let scheduler = MockNotificationScheduler()
        let (vm, _, _) = makeViewModel(scheduler: scheduler)

        // Enable first without awaiting
        vm.notificationsEnabled = true
        // Then disable immediately
        vm.notificationsEnabled = false

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertGreaterThanOrEqual(scheduler.cancelAllCallCount, 1)
    }

    func testScheduleReminders_passesSelectedDays() async {
        let scheduler = MockNotificationScheduler()
        scheduler.permissionGranted = true
        let (vm, _, _) = makeViewModel(scheduler: scheduler)

        vm.reminderDays = [.tuesday, .thursday]
        vm.notificationsEnabled = true

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        // tuesday.rawValue = 3, thursday.rawValue = 5
        XCTAssertEqual(Set(scheduler.lastScheduledDays), Set([Weekday.tuesday.rawValue, Weekday.thursday.rawValue]))
    }

    // MARK: - Notification Persistence

    func testNotificationSettings_persistReminderDays() {
        let suite = makeSuite()
        let (vm, _, _) = makeViewModel(defaults: suite)

        vm.reminderDays = [.saturday, .sunday]

        let (vm2, _, _) = makeViewModel(defaults: suite)
        XCTAssertEqual(vm2.reminderDays, [.saturday, .sunday])
    }

    func testNotificationSettings_persistReminderTime() {
        let suite = makeSuite()
        let (vm, _, _) = makeViewModel(defaults: suite)

        var c = DateComponents(); c.hour = 7; c.minute = 30
        vm.reminderTime = c

        let (vm2, _, _) = makeViewModel(defaults: suite)
        XCTAssertEqual(vm2.reminderTime.hour, 7)
        XCTAssertEqual(vm2.reminderTime.minute, 30)
    }

    // MARK: - Cloud Sync

    func testOnAppear_checksCloudAvailability() async {
        let cloud = MockCloudSyncService()
        let (vm, _, _) = makeViewModel(cloud: cloud)

        await vm.onAppear()

        XCTAssertEqual(cloud.checkAvailabilityCallCount, 1)
    }

    func testOnAppear_syncedState_reflectedInViewModel() async {
        let cloud = MockCloudSyncService()
        cloud.syncState = .synced
        let (vm, _, _) = makeViewModel(cloud: cloud)

        await vm.onAppear()

        XCTAssertEqual(vm.syncState, .synced)
    }

    func testOnAppear_errorState_reflectedInViewModel() async {
        let cloud = MockCloudSyncService()
        cloud.syncState = .error("Not signed in")
        let (vm, _, _) = makeViewModel(cloud: cloud)

        await vm.onAppear()

        if case .error(let msg) = vm.syncState {
            XCTAssertFalse(msg.isEmpty)
        } else {
            XCTFail("Expected .error sync state, got \(vm.syncState)")
        }
    }
}

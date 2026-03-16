import Foundation
import CloudKit
import CoreData
import Observation

// MARK: - CloudSyncState

/// Represents the current state of CloudKit synchronisation.
///
/// Designed to be consumed directly by SwiftUI views:
/// - `.idle`    — no sync in progress; all is well
/// - `.syncing` — a CloudKit import/export/setup operation is in flight
/// - `.synced`  — the last availability check confirmed iCloud is accessible
/// - `.error`   — the last sync attempt ended with a failure; the associated
///                `String` is a user-readable sentence suitable for display in a banner
/// - `.unknown` — the status has not yet been determined (initial state before first check)
enum CloudSyncState: Equatable {
    case idle
    case syncing
    case synced
    case error(String)
    case unknown
}

// MARK: - CloudSyncServiceProtocol

/// Protocol abstracting CloudKit sync so callers and tests can work against a
/// type-erased interface without a live iCloud account or CloudKit entitlement.
protocol CloudSyncServiceProtocol: AnyObject {

    /// `true` when an iCloud account is signed in on the device.
    ///
    /// Derived from `FileManager.default.ubiquityIdentityToken`; this is a
    /// lightweight, synchronous check that does not require a network call.
    var iCloudAvailable: Bool { get }

    /// Whether the user has opted in to iCloud sync.
    ///
    /// Persisted in `UserDefaults` so the preference survives termination.
    var isSyncEnabled: Bool { get }

    /// The current CloudKit sync state.
    var syncState: CloudSyncState { get }

    /// Checks iCloud availability and updates `syncState` to `.synced` or `.error`.
    ///
    /// This lightweight check uses `FileManager.ubiquityIdentityToken` and does
    /// not perform a network round-trip.
    func checkAvailability() async

    /// Opts the user in to iCloud sync.
    ///
    /// Records the preference to `UserDefaults`. This method is a no-op when
    /// `iCloudAvailable` is `false`.
    func enableSync()

    /// Opts the user out of iCloud sync.
    ///
    /// Clears the preference from `UserDefaults` and resets `syncState` to `.idle`.
    func disableSync()
}

// MARK: - CloudSyncService

/// Monitors CloudKit sync health and exposes a toggle for opt-in iCloud sync.
///
/// This service has two responsibilities:
/// 1. **Availability detection** — exposes `iCloudAvailable` using the
///    lightweight `FileManager.ubiquityIdentityToken` check and `checkAvailability()`
///    for an explicit status update.
/// 2. **Event monitoring** — listens for `NSPersistentCloudKitContainer.
///    eventChangedNotification` and maps the result to a `CloudSyncState`,
///    surfacing human-readable error messages for `CKError` codes.
///
/// Usage:
/// ```swift
/// let service = CloudSyncService.shared
/// await service.checkAvailability()
/// // Observe service.syncState in a SwiftUI view.
/// ```
@Observable
final class CloudSyncService: CloudSyncServiceProtocol {

    // MARK: - Singleton

    static let shared = CloudSyncService()

    // MARK: - Public State

    /// Whether iCloud sync is currently enabled. Backed by `UserDefaults`.
    private(set) var isSyncEnabled: Bool

    /// The current CloudKit sync state for UI consumption.
    private(set) var syncState: CloudSyncState = .unknown

    // MARK: - iCloud Availability

    /// Returns `true` when an iCloud account is signed in on the device.
    ///
    /// Uses `FileManager.default.ubiquityIdentityToken`, which is:
    /// - non-nil when iCloud Drive is enabled and an account is signed in
    /// - nil when there is no account or iCloud Drive is disabled in Settings
    ///
    /// This property is computed each time it is accessed so it reflects the
    /// current account state without requiring a dedicated refresh call.
    var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Private Properties

    private static let syncEnabledKey = "cloudSyncEnabled"
    private var notificationObserver: (any NSObjectProtocol)?

    // MARK: - Init / Deinit

    /// Creates a new `CloudSyncService`, restoring the persisted sync preference
    /// and beginning observation of CloudKit sync events.
    init() {
        self.isSyncEnabled = UserDefaults.standard.bool(forKey: CloudSyncService.syncEnabledKey)
        startMonitoringCloudKitEvents()
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - CloudSyncServiceProtocol

    /// Checks iCloud availability and updates `syncState` accordingly.
    ///
    /// Sets `syncState` to `.synced` when an iCloud account is signed in,
    /// or `.error` with a descriptive message when the user is signed out
    /// or iCloud Drive is disabled.
    func checkAvailability() async {
        if iCloudAvailable {
            syncState = .synced
        } else {
            syncState = .error("Sign in to iCloud in Settings to enable sync.")
        }
    }

    /// Enables iCloud sync, persisting the choice to `UserDefaults`.
    ///
    /// This method is a no-op when `iCloudAvailable` is `false` — the UI
    /// should disable the sync toggle in that case to prevent calling this.
    func enableSync() {
        guard iCloudAvailable else { return }
        UserDefaults.standard.set(true, forKey: CloudSyncService.syncEnabledKey)
        isSyncEnabled = true
        syncState = .idle
    }

    /// Disables iCloud sync, clearing the preference from `UserDefaults`.
    func disableSync() {
        UserDefaults.standard.set(false, forKey: CloudSyncService.syncEnabledKey)
        isSyncEnabled = false
        syncState = .idle
    }

    // MARK: - Private: Notification Monitoring

    /// Subscribes to `NSPersistentCloudKitContainer.eventChangedNotification`
    /// on the main queue so state updates are published on the main actor.
    private func startMonitoringCloudKitEvents() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudKitEventNotification(notification)
        }
    }

    /// Extracts the `NSPersistentCloudKitContainer.Event` from a notification
    /// and transitions `syncState` accordingly.
    private func handleCloudKitEventNotification(_ notification: Notification) {
        guard
            let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event
        else { return }

        if let error = event.error {
            syncState = .error(userReadableMessage(for: error))
        } else if event.endDate == nil {
            // endDate is nil while the event is still in progress.
            syncState = .syncing
        } else {
            syncState = .idle
        }
    }

    // MARK: - Private: Error Mapping

    /// Maps a raw sync error into a sentence a non-technical user can act on.
    private func userReadableMessage(for error: Error) -> String {
        guard let ckError = error as? CKError else {
            return "iCloud sync failed: \(error.localizedDescription)"
        }

        switch ckError.code {
        case .notAuthenticated:
            return "Sign in to iCloud in Settings to enable sync."
        case .networkUnavailable, .networkFailure:
            return "iCloud sync failed: check your internet connection."
        case .quotaExceeded:
            return "Your iCloud storage is full. Free up space to continue syncing."
        case .serverRejectedRequest:
            return "iCloud sync was rejected by the server. Try again later."
        case .zoneBusy:
            return "iCloud is busy. Sync will retry automatically."
        case .serviceUnavailable:
            return "iCloud service is temporarily unavailable. Try again later."
        case .permissionFailure:
            return "iCloud sync permission was denied. Check your iCloud settings."
        case .userDeletedZone:
            return "iCloud sync data was deleted. Re-enable sync to start fresh."
        case .changeTokenExpired:
            return "iCloud sync needs to reset. Disable and re-enable sync to continue."
        default:
            return "iCloud sync failed: \(ckError.localizedDescription)"
        }
    }
}

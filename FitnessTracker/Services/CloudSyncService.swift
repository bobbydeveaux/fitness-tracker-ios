import Foundation
import Observation

// MARK: - CloudSyncState

/// Represents the current iCloud sync status surfaced to the UI.
enum CloudSyncState: Equatable {
    /// The user is signed in and sync is working normally.
    case syncing
    /// The last sync completed successfully.
    case synced
    /// Sync is unavailable or encountered an error.
    case error(String)
    /// The status has not yet been determined (initial state).
    case unknown
}

// MARK: - CloudSyncServiceProtocol

/// Abstracts iCloud availability detection so callers and tests can work
/// against a type-erased interface.
protocol CloudSyncServiceProtocol: AnyObject {

    /// The current sync state. Observed by SwiftUI views.
    var syncState: CloudSyncState { get }

    /// Checks the current iCloud account status and updates `syncState`.
    func checkAvailability() async
}

// MARK: - CloudSyncService

/// Monitors iCloud account availability and publishes `CloudSyncState` for
/// the settings UI to display.
///
/// Because SwiftData with `.cloudKitDatabase` handles the actual data sync,
/// this service only needs to surface whether iCloud is reachable so the UI
/// can show a helpful error banner when the user is signed out or offline.
///
/// Usage:
/// ```swift
/// let service = CloudSyncService.shared
/// await service.checkAvailability()
/// // service.syncState == .synced or .error("…")
/// ```
@Observable
final class CloudSyncService: CloudSyncServiceProtocol {

    // MARK: - Singleton

    static let shared = CloudSyncService()

    // MARK: - State

    /// Published sync state. Updated by `checkAvailability()`.
    private(set) var syncState: CloudSyncState = .unknown

    // MARK: - Dependencies

    private let fileManager: FileManager

    // MARK: - Init

    /// Designated initialiser.
    /// - Parameter fileManager: Defaults to `.default`; injectable for testing.
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - CloudSyncServiceProtocol

    /// Checks iCloud availability by looking for an ubiquity identity token.
    ///
    /// `FileManager.ubiquityIdentityToken` is non-nil when the user is signed
    /// in to iCloud. A nil token means either the user is signed out or iCloud
    /// Drive is disabled — both conditions produce an `.error` state so the UI
    /// can guide the user to enable iCloud.
    ///
    /// This check is intentionally lightweight and can be called on any actor
    /// context; it does not perform a network round-trip.
    func checkAvailability() async {
        if fileManager.ubiquityIdentityToken != nil {
            syncState = .synced
        } else {
            syncState = .error("Sign in to iCloud in Settings to enable sync.")
        }
    }
}

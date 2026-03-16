import Foundation
import Observation

// MARK: - AppearanceMode

/// User-selectable colour-scheme override.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case dark   = "dark"
    case light  = "light"
    case system = "system"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark:   return "Dark"
        case .light:  return "Light"
        case .system: return "System"
        }
    }
}

// MARK: - SettingsViewModel

/// Coordinates appearance preferences, notification scheduling, and iCloud sync
/// state for the Settings feature.
///
/// Persists all user preferences to `UserDefaults` so they survive app termination.
/// On init, previously persisted values are restored automatically.
///
/// Usage in a SwiftUI view:
/// ```swift
/// @State private var viewModel = SettingsViewModel()
///
/// var body: some View {
///     SettingsView(viewModel: viewModel)
///         .task { await viewModel.onAppear() }
/// }
/// ```
@Observable
@MainActor
final class SettingsViewModel {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let appearanceMode       = "settings.appearanceMode"
        static let notificationsEnabled = "settings.notificationsEnabled"
        static let reminderDays         = "settings.reminderDays"
        static let reminderHour         = "settings.reminderHour"
        static let reminderMinute       = "settings.reminderMinute"
    }

    // MARK: - Observable State

    /// Current appearance override. Defaults to `.dark` to satisfy the acceptance criterion.
    var appearanceMode: AppearanceMode = .dark {
        didSet { persistAppearance() }
    }

    /// Whether workout reminder notifications are enabled.
    var notificationsEnabled: Bool = false {
        didSet { handleNotificationsToggle() }
    }

    /// Selected reminder days (used by `NotificationSettingsView`).
    var reminderDays: Set<Weekday> = [.monday, .wednesday, .friday] {
        didSet { scheduleIfNeeded() }
    }

    /// Reminder time stored as `DateComponents`. Defaults to 08:00.
    var reminderTime: DateComponents = {
        var c = DateComponents()
        c.hour = 8
        c.minute = 0
        return c
    }() {
        didSet { scheduleIfNeeded() }
    }

    /// iCloud sync state published by `CloudSyncService`.
    var syncState: CloudSyncState = .unknown

    // MARK: - Dependencies

    private let notificationScheduler: any NotificationSchedulerProtocol
    private let cloudSyncService: any CloudSyncServiceProtocol
    private let defaults: UserDefaults

    // MARK: - Init

    /// - Parameters:
    ///   - notificationScheduler: Defaults to `NotificationScheduler.shared`; inject a stub in tests.
    ///   - cloudSyncService: Defaults to `CloudSyncService.shared`; inject a stub in tests.
    ///   - defaults: Defaults to `.standard`; inject a custom suite in tests.
    init(
        notificationScheduler: any NotificationSchedulerProtocol = NotificationScheduler.shared,
        cloudSyncService: any CloudSyncServiceProtocol = CloudSyncService.shared,
        defaults: UserDefaults = .standard
    ) {
        self.notificationScheduler = notificationScheduler
        self.cloudSyncService = cloudSyncService
        self.defaults = defaults
        restorePersistedSettings()
    }

    // MARK: - Lifecycle

    /// Call from the view's `.task {}` modifier to load cloud sync status.
    func onAppear() async {
        await cloudSyncService.checkAvailability()
        syncState = cloudSyncService.syncState
    }

    // MARK: - Private – Persistence

    private func restorePersistedSettings() {
        // Appearance
        if let raw = defaults.string(forKey: Keys.appearanceMode),
           let mode = AppearanceMode(rawValue: raw) {
            appearanceMode = mode
        }
        // Notifications
        if defaults.object(forKey: Keys.notificationsEnabled) != nil {
            notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        }
        // Reminder days
        if let rawValues = defaults.array(forKey: Keys.reminderDays) as? [Int] {
            let restored = rawValues.compactMap { Weekday(rawValue: $0) }
            if !restored.isEmpty {
                reminderDays = Set(restored)
            }
        }
        // Reminder time
        let hour   = defaults.integer(forKey: Keys.reminderHour)
        let minute = defaults.integer(forKey: Keys.reminderMinute)
        if hour != 0 || minute != 0 {
            var c = DateComponents()
            c.hour   = hour
            c.minute = minute
            reminderTime = c
        }
    }

    private func persistAppearance() {
        defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
    }

    private func persistNotifications() {
        defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
        defaults.set(reminderDays.map(\.rawValue), forKey: Keys.reminderDays)
        defaults.set(reminderTime.hour ?? 8, forKey: Keys.reminderHour)
        defaults.set(reminderTime.minute ?? 0, forKey: Keys.reminderMinute)
    }

    // MARK: - Private – Notification Scheduling

    private func handleNotificationsToggle() {
        persistNotifications()
        if notificationsEnabled {
            Task { [weak self] in
                guard let self else { return }
                await self.notificationScheduler.requestPermission()
                if self.notificationScheduler.authorizationStatus == .authorized {
                    await self.notificationScheduler.scheduleReminders(
                        days: Array(self.reminderDays.map(\.rawValue)),
                        time: self.reminderTime
                    )
                } else {
                    // Permission was denied — revert toggle without triggering another write.
                    self.notificationsEnabled = false
                }
            }
        } else {
            Task { [weak self] in
                await self?.notificationScheduler.cancelAll()
            }
        }
    }

    private func scheduleIfNeeded() {
        persistNotifications()
        guard notificationsEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.notificationScheduler.scheduleReminders(
                days: Array(self.reminderDays.map(\.rawValue)),
                time: self.reminderTime
            )
        }
    }
}

import Foundation
import UserNotifications

// MARK: - NotificationSchedulerProtocol

/// Abstracts local-notification scheduling so callers and tests can work
/// against a type-erased interface without depending on `UNUserNotificationCenter`.
protocol NotificationSchedulerProtocol: AnyObject {

    /// Requests notification authorisation (alert + sound + badge).
    /// - Returns: `true` if the user granted permission, `false` otherwise.
    func requestPermission() async -> Bool

    /// Schedules daily workout-reminder notifications on the supplied weekdays
    /// at the given time-of-day.
    ///
    /// Any previously scheduled reminders are cancelled before the new set is
    /// registered so the active schedule always matches the user's preferences.
    ///
    /// - Parameters:
    ///   - days: A set of `Weekday` values (e.g. `[.monday, .wednesday, .friday]`).
    ///   - time: The `DateComponents` representing the hour and minute at which
    ///     the notification should fire each scheduled day.
    func scheduleReminders(days: Set<Weekday>, time: DateComponents) async

    /// Cancels all pending reminder notifications scheduled by this service.
    func cancelAll()
}

// MARK: - Weekday

/// Strongly-typed weekday enum using `Calendar`-compatible raw values (1 = Sunday … 7 = Saturday).
enum Weekday: Int, CaseIterable, Identifiable, Codable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    /// Short display label shown in the weekday-selection grid.
    var shortLabel: String {
        switch self {
        case .sunday:    return "Su"
        case .monday:    return "Mo"
        case .tuesday:   return "Tu"
        case .wednesday: return "We"
        case .thursday:  return "Th"
        case .friday:    return "Fr"
        case .saturday:  return "Sa"
        }
    }

    /// Full display label.
    var fullLabel: String {
        switch self {
        case .sunday:    return "Sunday"
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        }
    }
}

// MARK: - NotificationScheduler

/// Wraps `UNUserNotificationCenter` to schedule and cancel workout reminders.
///
/// All notifications share the category identifier `com.fitnessTracker.reminder`
/// and are identified by `com.fitnessTracker.reminder.<weekdayRawValue>` so
/// individual days can be targeted for cancellation.
///
/// Usage:
/// ```swift
/// let scheduler = NotificationScheduler.shared
/// let granted = await scheduler.requestPermission()
/// if granted {
///     var time = DateComponents(); time.hour = 8; time.minute = 0
///     await scheduler.scheduleReminders(days: [.monday, .wednesday, .friday], time: time)
/// }
/// ```
final class NotificationScheduler: NotificationSchedulerProtocol {

    // MARK: - Singleton

    static let shared = NotificationScheduler()

    // MARK: - Constants

    private static let categoryIdentifier = "com.fitnessTracker.reminder"
    private static let identifierPrefix   = "com.fitnessTracker.reminder."

    // MARK: - Properties

    private let center: UNUserNotificationCenter

    // MARK: - Init

    /// Designated initialiser.
    /// - Parameter center: Defaults to `.current()`; injectable for testing.
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    // MARK: - NotificationSchedulerProtocol

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("[NotificationScheduler] Authorization error: \(error.localizedDescription)")
            return false
        }
    }

    func scheduleReminders(days: Set<Weekday>, time: DateComponents) async {
        cancelAll()

        guard !days.isEmpty else { return }

        for day in days {
            var trigger = DateComponents()
            trigger.hour = time.hour
            trigger.minute = time.minute
            trigger.weekday = day.rawValue

            let content = UNMutableNotificationContent()
            content.title = "Time to Work Out!"
            content.body  = "Your \(day.fullLabel) workout is waiting for you 💪"
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier

            let triggerValue = UNCalendarNotificationTrigger(
                dateMatching: trigger,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + String(day.rawValue),
                content: content,
                trigger: triggerValue
            )

            do {
                try await center.add(request)
            } catch {
                print("[NotificationScheduler] Failed to schedule \(day.fullLabel): \(error.localizedDescription)")
            }
        }
    }

    func cancelAll() {
        let identifiers = Weekday.allCases.map { Self.identifierPrefix + String($0.rawValue) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

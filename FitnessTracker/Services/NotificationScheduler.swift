import Foundation
import UserNotifications
import Observation

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

// MARK: - NotificationCenterProtocol

/// Internal abstraction over `UNUserNotificationCenter` that enables injecting
/// a test double without touching the real notification subsystem.
protocol NotificationCenterProtocol: AnyObject {

    /// Requests authorisation for the specified notification options.
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    /// Returns all notification requests currently waiting to be delivered.
    func pendingNotificationRequests() async -> [UNNotificationRequest]

    /// Cancels the pending notification requests identified by the given strings.
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])

    /// Schedules a local notification request.
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: NotificationCenterProtocol {}

// MARK: - NotificationSchedulerProtocol

/// Protocol that abstracts `UNUserNotificationCenter` scheduling so that
/// callers and tests can work against a type-erased interface.
protocol NotificationSchedulerProtocol: AnyObject {

    /// The current `UNAuthorizationStatus` for the app's notifications.
    ///
    /// Starts as `.notDetermined`. Updated after each call to `requestPermission()`.
    var authorizationStatus: UNAuthorizationStatus { get }

    /// Requests notification permission from the user and updates `authorizationStatus`.
    func requestPermission() async

    /// Removes any previously scheduled fitness reminders and schedules one
    /// `UNNotificationRequest` per entry in `days` at the specified `time`.
    ///
    /// - Parameters:
    ///   - days: Calendar weekday values (1 = Sunday … 7 = Saturday) to receive a reminder.
    ///   - time: `DateComponents` containing at minimum `hour` and `minute`.
    func scheduleReminders(days: [Int], time: DateComponents) async

    /// Cancels all pending notifications whose identifier begins with the
    /// fitness-reminder prefix.
    func cancelAll() async
}

// MARK: - NotificationScheduler

/// Singleton wrapping `UNUserNotificationCenter` for scheduling recurring
/// workout-reminder notifications.
///
/// All scheduling operations use the `fitness-reminder-` identifier prefix so
/// they can be targeted precisely without touching other notification categories
/// the app may add in the future.
///
/// Usage:
/// ```swift
/// let scheduler = NotificationScheduler.shared
/// await scheduler.requestPermission()
/// await scheduler.scheduleReminders(days: [2, 4, 6], time: DateComponents(hour: 8, minute: 0))
/// ```
@Observable
final class NotificationScheduler: NotificationSchedulerProtocol {

    // MARK: - Singleton

    /// The shared application-wide instance. Prefer this over creating additional
    /// instances — `init(center:)` is internal to allow test injection only.
    static let shared = NotificationScheduler()

    // MARK: - Published State

    /// The most recently resolved `UNAuthorizationStatus`.
    ///
    /// Starts as `.notDetermined` and is updated whenever `requestPermission()` resolves.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Constants

    /// Identifier prefix used for all fitness-reminder notifications.
    ///
    /// Each reminder request identifier is formed as `"fitness-reminder-<weekday>"`,
    /// e.g. `"fitness-reminder-2"` for Monday.
    static let identifierPrefix = "fitness-reminder-"

    // MARK: - Private

    private let center: any NotificationCenterProtocol

    // MARK: - Init

    /// Designated initialiser. Use `.shared` in production; inject a mock
    /// `NotificationCenterProtocol` in unit tests.
    init(center: any NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    // MARK: - Permission

    /// Requests `.alert`, `.sound`, and `.badge` authorisation from the user.
    ///
    /// On success the granted/denied decision is reflected in `authorizationStatus`.
    /// If the system throws (e.g. the call is made from an unsupported context),
    /// the error is logged and `authorizationStatus` is set to `.denied` so the
    /// UI can surface a helpful message rather than hanging indefinitely.
    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            print("[NotificationScheduler] Authorization error: \(error.localizedDescription)")
            authorizationStatus = .denied
        }
    }

    // MARK: - Scheduling

    /// Removes all existing fitness-reminder requests, then creates one repeating
    /// `UNCalendarNotificationTrigger` per entry in `days`.
    ///
    /// Calling this method a second time safely replaces any previously scheduled
    /// set of reminders — old requests are removed before new ones are added.
    ///
    /// - Parameters:
    ///   - days: Calendar weekday numbers in the range 1–7 (1 = Sunday).
    ///   - time: `DateComponents` specifying `hour` and `minute` for the daily trigger.
    func scheduleReminders(days: [Int], time: DateComponents) async {
        // Remove existing fitness-reminder notifications first.
        let pending = await center.pendingNotificationRequests()
        let existingIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existingIDs)

        // Schedule one repeating request per requested weekday.
        for day in days {
            var triggerComponents = DateComponents()
            triggerComponents.hour = time.hour
            triggerComponents.minute = time.minute
            triggerComponents.weekday = day

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: triggerComponents,
                repeats: true
            )

            let content = UNMutableNotificationContent()
            content.title = "Fitness Reminder"
            content.body = "Time for your workout. Keep the streak alive!"
            content.sound = .default

            let identifier = "\(Self.identifierPrefix)\(day)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                print("[NotificationScheduler] Failed to schedule reminder for weekday \(day): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cancellation

    /// Removes all pending notifications whose identifier begins with
    /// `"fitness-reminder-"`.
    ///
    /// This leaves any non-fitness notifications from other parts of the app
    /// (e.g. meal-log reminders) untouched.
    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let fitnessIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: fitnessIDs)
    }
}

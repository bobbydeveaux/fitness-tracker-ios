import SwiftUI

// MARK: - NotificationSettingsView

/// Detailed notification-schedule screen pushed from `SettingsView`.
///
/// Presents:
/// - A 7-column weekday selection grid where tapping a day toggles it on/off.
/// - A `DatePicker` (hours and minutes only) for the daily reminder time.
///
/// All changes are written back to the injected `SettingsViewModel` which
/// persists them to `UserDefaults` and re-schedules notifications via
/// `NotificationScheduler.scheduleReminders(days:time:)`.
struct NotificationSettingsView: View {

    // MARK: - Dependencies

    @Bindable var viewModel: SettingsViewModel

    // MARK: - Private State

    /// `Date` used to drive the `DatePicker`; kept in sync with `viewModel.reminderTime`.
    @State private var reminderDate: Date = {
        var c = DateComponents()
        c.hour = 8; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()

    // MARK: - Body

    var body: some View {
        Form {
            weekdaySection
            timeSection
        }
        .navigationTitle("Reminder Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Sync the local Date state with the view-model's DateComponents.
            if let hour = viewModel.reminderTime.hour,
               let minute = viewModel.reminderTime.minute {
                var c = DateComponents()
                c.hour = hour; c.minute = minute
                if let date = Calendar.current.date(from: c) {
                    reminderDate = date
                }
            }
        }
        .onChange(of: reminderDate) { _, newDate in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
            viewModel.reminderTime = comps
        }
    }

    // MARK: - Sections

    private var weekdaySection: some View {
        Section("Active Days") {
            WeekdayGridView(selectedDays: $viewModel.reminderDays)
                .padding(.vertical, 4)
        }
    }

    private var timeSection: some View {
        Section("Reminder Time") {
            DatePicker(
                "Time",
                selection: $reminderDate,
                displayedComponents: [.hourAndMinute]
            )
        }
    }
}

// MARK: - WeekdayGridView

/// A 7-column horizontal grid of day-of-week pills.
///
/// Tapping a pill toggles inclusion in the `selectedDays` binding.
struct WeekdayGridView: View {

    @Binding var selectedDays: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                DayPill(day: day, isSelected: selectedDays.contains(day)) {
                    toggleDay(day)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func toggleDay(_ day: Weekday) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
}

// MARK: - DayPill

private struct DayPill: View {

    let day: Weekday
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(day.shortLabel)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.fullLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("Notification Settings") {
    NavigationStack {
        NotificationSettingsView(viewModel: SettingsViewModel())
    }
}

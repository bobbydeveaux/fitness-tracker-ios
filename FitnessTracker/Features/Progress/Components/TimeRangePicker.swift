import SwiftUI

// MARK: - TimeRangePicker

/// A segmented control for choosing the active time range in the Progress screen.
///
/// Binds directly to `ProgressViewModel.selectedRange`. Changing the selection
/// automatically triggers a data reload in the view model.
///
/// ```swift
/// TimeRangePicker(selectedRange: $viewModel.selectedRange)
/// ```
struct TimeRangePicker: View {

    // MARK: - Properties

    /// The currently selected time range. Two-way binding drives the view model reload.
    @Binding var selectedRange: TimeRange

    // MARK: - Body

    var body: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.displayTitle).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Select time range")
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var range: TimeRange = .oneMonth

    VStack(spacing: 24) {
        TimeRangePicker(selectedRange: $range)
            .padding(.horizontal)

        Text("Selected: \(range.displayTitle)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .padding()
}

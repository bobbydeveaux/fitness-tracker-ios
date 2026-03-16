import SwiftUI

// MARK: - MeasurementLogView

/// A modal form that lets the user record a new body measurement.
///
/// The form exposes a picker for `BodyMetricType`, a numeric value field that
/// adjusts its keyboard and unit label based on the selected type, and a date
/// picker for when the measurement was taken. Tapping "Save" calls the provided
/// `onSave` closure and dismisses the sheet.
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showingLog) {
///     MeasurementLogView { type, value, date in
///         Task { await viewModel.logMeasurement(type: type, value: value, date: date, for: profile) }
///     }
/// }
/// ```
struct MeasurementLogView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedType: BodyMetricType = .weight
    @State private var valueText: String = ""
    @State private var date: Date = .now

    // MARK: - Callbacks

    /// Called with (type, value, date) when the user taps Save.
    let onSave: (BodyMetricType, Double, Date) -> Void

    // MARK: - Computed

    private var parsedValue: Double? {
        Double(valueText.replacingOccurrences(of: ",", with: "."))
    }

    private var isFormValid: Bool {
        guard let v = parsedValue else { return false }
        return v > 0
    }

    private var unitLabel: String {
        switch selectedType {
        case .weight:            return "kg"
        case .bodyFatPercentage: return "%"
        default:                 return "cm"
        }
    }

    private var valuePlaceholder: String {
        switch selectedType {
        case .weight:            return "e.g. 75.5"
        case .bodyFatPercentage: return "e.g. 18.0"
        default:                 return "e.g. 80.0"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Measurement type picker
                Section("Measurement Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(BodyMetricType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Value entry
                Section {
                    HStack {
                        TextField(valuePlaceholder, text: $valueText)
                            .keyboardType(.decimalPad)
                        Text(unitLabel)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } header: {
                    Text("Value")
                } footer: {
                    if !valueText.isEmpty && parsedValue == nil {
                        Text("Please enter a valid number.")
                            .foregroundStyle(.red)
                    }
                }

                // Date picker
                Section("Date & Time") {
                    DatePicker(
                        "When",
                        selection: $date,
                        in: ...Date.now,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }
            }
            .navigationTitle("Log Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = parsedValue else { return }
                        onSave(selectedType, value, date)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - BodyMetricType + Helpers

extension BodyMetricType: CaseIterable {
    public static var allCases: [BodyMetricType] {
        [.weight, .chest, .waist, .hips, .neck, .thigh, .arm, .bodyFatPercentage]
    }

    /// A user-facing display name for each measurement type.
    var displayName: String {
        switch self {
        case .weight:            return "Weight"
        case .chest:             return "Chest"
        case .waist:             return "Waist"
        case .hips:              return "Hips"
        case .neck:              return "Neck"
        case .thigh:             return "Thigh"
        case .arm:               return "Arm"
        case .bodyFatPercentage: return "Body Fat %"
        }
    }
}

// MARK: - Preview

#Preview {
    MeasurementLogView { type, value, date in
        print("Saved: \(type.displayName) = \(value) on \(date)")
    }
}

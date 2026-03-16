import SwiftUI

// MARK: - ExerciseSetRow

/// An interactive row for a single set within a `SessionView` exercise table.
///
/// Shows:
/// - Set number badge
/// - Weight and reps input fields (pre-filled from the last session)
/// - A "previous session" reference value alongside each input
/// - A PR badge when the set is flagged as a personal record
/// - A checkmark button to mark the set complete
///
/// Binds to a `SetRow` value via `Binding` so changes flow back to
/// `SessionViewModel` automatically.
struct ExerciseSetRow: View {

    // MARK: - Bindings

    @Binding var row: SetRow
    let setNumber: Int
    let previousWeight: Double?
    let previousReps: Int?
    let onComplete: () -> Void

    // MARK: - Local State

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            setNumberBadge
            weightField
            repsField
            if row.isPR {
                prBadge
            }
            completeButton
        }
        .padding(.vertical, 4)
        .onAppear { syncTextFields() }
        .opacity(row.isComplete ? 0.6 : 1.0)
    }

    // MARK: - Subviews

    private var setNumberBadge: some View {
        Text("\(setNumber)")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .frame(width: 24)
    }

    private var weightField: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)
                .disabled(row.isComplete)
                .onChange(of: weightText) { _, newValue in
                    row.weightKg = Double(newValue) ?? row.weightKg
                }
            if let prev = previousWeight {
                Text(String(format: "%.1f kg", prev))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var repsField: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 56)
                .disabled(row.isComplete)
                .onChange(of: repsText) { _, newValue in
                    row.reps = Int(newValue) ?? row.reps
                }
            if let prev = previousReps {
                Text("\(prev) reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var prBadge: some View {
        Label("PR", systemImage: "trophy.fill")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.orange, in: Capsule())
    }

    private var completeButton: some View {
        Button {
            syncRowFromText()
            onComplete()
        } label: {
            Image(systemName: row.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(row.isComplete ? .green : .secondary)
        }
        .disabled(row.isComplete)
        .frame(width: 36)
    }

    // MARK: - Helpers

    private func syncTextFields() {
        weightText = row.weightKg > 0 ? String(format: "%.1f", row.weightKg) : ""
        repsText = row.reps > 0 ? "\(row.reps)" : ""
    }

    private func syncRowFromText() {
        if let w = Double(weightText) { row.weightKg = w }
        if let r = Int(repsText) { row.reps = r }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var row = SetRow(
        id: UUID(),
        setIndex: 0,
        weightKg: 100,
        reps: 5,
        rpe: 8,
        isComplete: false,
        isPR: false
    )

    return VStack(spacing: 12) {
        ExerciseSetRow(
            row: $row,
            setNumber: 1,
            previousWeight: 95,
            previousReps: 5,
            onComplete: { row.isComplete = true }
        )

        var prRow = SetRow(id: UUID(), setIndex: 1, weightKg: 105, reps: 5, rpe: nil, isComplete: true, isPR: true)
        ExerciseSetRow(
            row: .constant(prRow),
            setNumber: 2,
            previousWeight: 100,
            previousReps: 5,
            onComplete: {}
        )
    }
    .padding()
}

import SwiftUI

// MARK: - ExerciseSetRow

/// A single set row within the active session exercise table.
///
/// Provides editable weight and reps fields, shows the previous-best
/// reference inline, and displays a completion checkbox. A trophy badge
/// appears when the set is marked as a personal record.
struct ExerciseSetRow: View {

    // MARK: - Input

    let setIndex: Int
    let set: LoggedSet
    let previousBest: (weightKg: Double, reps: Int)?
    let onComplete: (_ weightKg: Double, _ reps: Int, _ rpe: Double?) -> Void

    // MARK: - Local state

    @State private var weightText: String
    @State private var repsText: String
    @State private var rpeText: String
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case weight, reps, rpe }

    // MARK: - Init

    init(
        setIndex: Int,
        set: LoggedSet,
        previousBest: (weightKg: Double, reps: Int)?,
        onComplete: @escaping (_ weightKg: Double, _ reps: Int, _ rpe: Double?) -> Void
    ) {
        self.setIndex = setIndex
        self.set = set
        self.previousBest = previousBest
        self.onComplete = onComplete
        // Pre-populate with existing values so partially filled rows persist.
        _weightText = State(initialValue: set.weightKg > 0 ? String(format: "%.1f", set.weightKg) : "")
        _repsText = State(initialValue: set.reps > 0 ? "\(set.reps)" : "")
        _rpeText = State(initialValue: set.rpe.map { String(format: "%.1f", $0) } ?? "")
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                setNumberBadge

                inputFields

                completeButton
            }

            if let best = previousBest, !set.isComplete {
                previousBestRow(best: best)
            }
        }
        .padding(.vertical, 6)
        .background(
            set.isPR
                ? RoundedRectangle(cornerRadius: 10)
                    .fill(Color.yellow.opacity(0.08))
                : nil
        )
    }

    // MARK: - Subviews

    private var setNumberBadge: some View {
        ZStack {
            Circle()
                .fill(set.isComplete ? Color.accentColor : Color(.systemGray5))
                .frame(width: 28, height: 28)
            Text("\(setIndex + 1)")
                .font(.caption.bold())
                .foregroundStyle(set.isComplete ? .white : .secondary)
        }
    }

    private var inputFields: some View {
        HStack(spacing: 8) {
            // Weight field
            VStack(spacing: 2) {
                TextField("0.0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 64)
                    .focused($focusedField, equals: .weight)
                    .disabled(set.isComplete)
                Text("kg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("×")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Reps field
            VStack(spacing: 2) {
                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 44)
                    .focused($focusedField, equals: .reps)
                    .disabled(set.isComplete)
                Text("reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("@")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // RPE field (optional)
            VStack(spacing: 2) {
                TextField("–", text: $rpeText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 36)
                    .focused($focusedField, equals: .rpe)
                    .disabled(set.isComplete)
                Text("RPE")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // PR trophy badge
            if set.isPR {
                Label("PR", systemImage: "trophy.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.yellow.opacity(0.15))
                    )
            }
        }
    }

    private var completeButton: some View {
        Button(action: handleComplete) {
            Image(systemName: set.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(set.isComplete ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(set.isComplete)
    }

    private func previousBestRow(best: (weightKg: Double, reps: Int)) -> some View {
        HStack {
            Spacer()
                .frame(width: 40)
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Previous: \(String(format: "%.1f", best.weightKg)) kg × \(best.reps)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Actions

    private func handleComplete() {
        focusedField = nil
        guard let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
              let reps = Int(repsText),
              weight > 0, reps > 0 else { return }
        let rpe = Double(rpeText.replacingOccurrences(of: ",", with: "."))
        onComplete(weight, reps, rpe)
    }
}

// MARK: - Preview

#Preview("ExerciseSetRow – incomplete") {
    let set = LoggedSet(setIndex: 0, weightKg: 0, reps: 0, sortOrder: 0)
    return ExerciseSetRow(
        setIndex: 0,
        set: set,
        previousBest: (weightKg: 100.0, reps: 5),
        onComplete: { _, _, _ in }
    )
    .padding()
}

#Preview("ExerciseSetRow – completed PR") {
    let set = LoggedSet(setIndex: 0, weightKg: 102.5, reps: 5, sortOrder: 0)
    set.isComplete = true
    set.isPR = true
    return ExerciseSetRow(
        setIndex: 0,
        set: set,
        previousBest: (weightKg: 100.0, reps: 5),
        onComplete: { _, _, _ in }
    )
    .padding()
}

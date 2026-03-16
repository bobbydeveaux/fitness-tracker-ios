import SwiftUI

// MARK: - MacroSummaryBar

/// A compact summary bar that displays the user's consumed macronutrients
/// versus their daily targets as a set of labelled progress bars.
///
/// Pass `consumed*` values from `NutritionViewModel` and `target*` from the
/// active `UserProfile`. Both sets update reactively when the view model
/// publishes new macro totals.
///
/// ```swift
/// MacroSummaryBar(
///     consumedKcal: viewModel.totalKcal,
///     consumedProteinG: viewModel.totalProteinG,
///     consumedCarbG: viewModel.totalCarbG,
///     consumedFatG: viewModel.totalFatG,
///     targetKcal: profile.tdeeKcal,
///     targetProteinG: profile.proteinTargetG,
///     targetCarbG: profile.carbTargetG,
///     targetFatG: profile.fatTargetG
/// )
/// ```
struct MacroSummaryBar: View {

    // MARK: - Properties

    let consumedKcal: Double
    let consumedProteinG: Double
    let consumedCarbG: Double
    let consumedFatG: Double

    let targetKcal: Double
    let targetProteinG: Double
    let targetCarbG: Double
    let targetFatG: Double

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Calorie ring + label row
            HStack(spacing: 16) {
                CalorieRing(consumed: consumedKcal, target: targetKcal)
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Calories")
                        .font(.subheadline.weight(.semibold))
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.0f", consumedKcal))
                            .font(.title2.bold())
                        Text("/ \(Int(targetKcal)) kcal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(remainingKcalText)
                        .font(.caption)
                        .foregroundStyle(calorieProgressColor)
                }

                Spacer()
            }

            // Macro progress bars
            VStack(spacing: 8) {
                MacroProgressRow(
                    label: "Protein",
                    consumed: consumedProteinG,
                    target: targetProteinG,
                    color: .red
                )
                MacroProgressRow(
                    label: "Carbs",
                    consumed: consumedCarbG,
                    target: targetCarbG,
                    color: .blue
                )
                MacroProgressRow(
                    label: "Fat",
                    consumed: consumedFatG,
                    target: targetFatG,
                    color: .yellow
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Helpers

    private var remainingKcal: Double { targetKcal - consumedKcal }

    private var remainingKcalText: String {
        if remainingKcal > 0 {
            return "\(Int(remainingKcal)) kcal remaining"
        } else if remainingKcal == 0 {
            return "Target reached"
        } else {
            return "\(Int(-remainingKcal)) kcal over target"
        }
    }

    private var calorieProgressColor: Color {
        if consumedKcal <= targetKcal { return .secondary }
        return .red
    }
}

// MARK: - CalorieRing

private struct CalorieRing: View {
    let consumed: Double
    let target: Double

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(consumed / target, 1.0)
    }

    private var color: Color {
        progress > 1.0 ? .red : .orange
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemFill), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
        }
    }
}

// MARK: - MacroProgressRow

private struct MacroProgressRow: View {
    let label: String
    let consumed: Double
    let target: Double
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(consumed / target, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f / %.0f g", consumed, target))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Preview

#Preview {
    MacroSummaryBar(
        consumedKcal: 1450,
        consumedProteinG: 95,
        consumedCarbG: 160,
        consumedFatG: 45,
        targetKcal: 2136,
        targetProteinG: 160,
        targetCarbG: 213,
        targetFatG: 71
    )
    .padding()
}

import SwiftUI

// MARK: - ExerciseDetailView

/// Shows full metadata for a single exercise: name, muscle group, equipment,
/// instructions, and a muscle-diagram placeholder.
///
/// Designed to be pushed onto a `NavigationStack` from `ExerciseLibraryView`.
struct ExerciseDetailView: View {

    // MARK: - Properties

    let exercise: Exercise

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                metadataSection
                instructionsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Subviews

    /// Muscle diagram placeholder and exercise name.
    private var headerSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 180)

            VStack(spacing: 12) {
                Image(systemName: muscleGroupSystemImage(for: exercise.muscleGroup))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(Color.accentColor)

                Text(exercise.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }

    /// Muscle group and equipment badges in a card.
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            HStack(spacing: 16) {
                MetadataRow(
                    icon: "figure.strengthtraining.traditional",
                    label: "Muscle Group",
                    value: exercise.muscleGroup
                )
                Spacer()
                MetadataRow(
                    icon: "dumbbell.fill",
                    label: "Equipment",
                    value: exercise.equipment
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )

            HStack(spacing: 8) {
                MuscleGroupBadge(muscleGroup: exercise.muscleGroup)
                EquipmentBadge(equipment: exercise.equipment)
            }
        }
    }

    /// Step-by-step instructions in a card.
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.headline)

            Text(exercise.instructions)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }

    // MARK: - Helpers

    /// Returns a SF Symbol name that loosely represents the primary muscle group.
    private func muscleGroupSystemImage(for muscleGroup: String) -> String {
        switch muscleGroup.lowercased() {
        case "chest":
            return "figure.arms.open"
        case "back":
            return "figure.strengthtraining.traditional"
        case "shoulders":
            return "figure.cooldown"
        case "biceps", "triceps", "forearms":
            return "figure.boxing"
        case "quadriceps", "hamstrings", "calves", "glutes":
            return "figure.run"
        case "core":
            return "figure.core.training"
        default:
            return "figure.mixed.cardio"
        }
    }
}

// MARK: - MetadataRow

private struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.bold())
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ExerciseDetailView(
            exercise: Exercise(
                exerciseID: "preview-001",
                name: "Barbell Bench Press",
                muscleGroup: "Chest",
                equipment: "Barbell",
                instructions: "Lie flat on a bench, grip the bar slightly wider than shoulder-width. Lower the bar to your mid-chest, then press back up to full arm extension. Keep your feet flat on the floor and maintain a slight arch in your lower back.",
                imageName: "barbell_bench_press"
            )
        )
    }
}

import SwiftUI

// MARK: - ExerciseLibraryView

/// Displays the full bundled exercise library with Picker filters for muscle
/// group and equipment. The list updates instantly whenever either filter changes.
///
/// Tapping an exercise row navigates to `ExerciseDetailView`.
struct ExerciseLibraryView: View {

    // MARK: - Dependencies

    let exerciseLibraryService: ExerciseLibraryService

    // MARK: - State

    @State private var selectedMuscleGroup: String = FilterOption.all
    @State private var selectedEquipment: String = FilterOption.all
    @State private var searchText: String = ""

    // MARK: - Constants

    private enum FilterOption {
        static let all = "All"
    }

    private let muscleGroups: [String] = [
        FilterOption.all,
        "Back", "Biceps", "Calves", "Chest", "Core",
        "Forearms", "Glutes", "Hamstrings", "Quadriceps", "Shoulders", "Triceps"
    ]

    private let equipmentOptions: [String] = [
        FilterOption.all,
        "Barbell", "Bodyweight", "Cable", "Dumbbell", "Machine", "Other"
    ]

    // MARK: - Computed

    private var filteredExercises: [Exercise] {
        var exercises: [Exercise]

        if selectedMuscleGroup == FilterOption.all && selectedEquipment == FilterOption.all {
            exercises = exerciseLibraryService.allExercises()
        } else if selectedMuscleGroup == FilterOption.all {
            exercises = exerciseLibraryService.exercises(forEquipment: selectedEquipment)
        } else if selectedEquipment == FilterOption.all {
            exercises = exerciseLibraryService.exercises(forMuscleGroup: selectedMuscleGroup)
        } else {
            exercises = exerciseLibraryService.exercises(
                forMuscleGroup: selectedMuscleGroup,
                equipment: selectedEquipment
            )
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            exercises = exercises.filter { $0.name.lowercased().contains(query) }
        }

        return exercises
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            exerciseList
        }
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search exercises…")
    }

    // MARK: - Subviews

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterPicker(
                    label: "Muscle Group",
                    selection: $selectedMuscleGroup,
                    options: muscleGroups
                )

                Divider()
                    .frame(height: 28)

                FilterPicker(
                    label: "Equipment",
                    selection: $selectedEquipment,
                    options: equipmentOptions
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemBackground))
    }

    private var exerciseList: some View {
        Group {
            if filteredExercises.isEmpty {
                ContentUnavailableView.search(text: searchText.isEmpty
                    ? "\(selectedMuscleGroup) / \(selectedEquipment)"
                    : searchText)
            } else {
                List(filteredExercises, id: \.exerciseID) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        ExerciseRowView(exercise: exercise)
                    }
                }
                .listStyle(.plain)
                .animation(.default, value: filteredExercises.map(\.exerciseID))
            }
        }
    }
}

// MARK: - FilterPicker

private struct FilterPicker: View {
    let label: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        Label(
                            option,
                            systemImage: selection == option ? "checkmark" : ""
                        )
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selection)
                        .font(.subheadline.bold())
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground), in: Capsule())
            }
        }
    }
}

// MARK: - ExerciseRowView

private struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.body)
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                MuscleGroupBadge(muscleGroup: exercise.muscleGroup)
                EquipmentBadge(equipment: exercise.equipment)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - MuscleGroupBadge

struct MuscleGroupBadge: View {
    let muscleGroup: String

    var body: some View {
        Text(muscleGroup)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(muscleGroupColor, in: Capsule())
    }

    private var muscleGroupColor: Color {
        switch muscleGroup.lowercased() {
        case "chest":      return .red
        case "back":       return .blue
        case "shoulders":  return .purple
        case "biceps":     return .orange
        case "triceps":    return .pink
        case "quadriceps": return .green
        case "hamstrings": return .teal
        case "glutes":     return .indigo
        case "core":       return .yellow
        case "calves":     return .mint
        case "forearms":   return .brown
        default:           return .gray
        }
    }
}

// MARK: - EquipmentBadge

struct EquipmentBadge: View {
    let equipment: String

    var body: some View {
        Text(equipment)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.tertiarySystemBackground), in: Capsule())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ExerciseLibraryView(
            exerciseLibraryService: ExerciseLibraryService()
        )
    }
}

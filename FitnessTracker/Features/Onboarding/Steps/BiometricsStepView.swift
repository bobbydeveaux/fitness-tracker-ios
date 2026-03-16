import SwiftUI

// MARK: - BiometricsStepView

/// Second onboarding step: collects name, age, gender, height, and weight.
///
/// Uses numeric keyboards for height and weight fields, Steppers for age,
/// and a Picker for gender. All interactive controls bind directly to the
/// shared `OnboardingViewModel`.
struct BiometricsStepView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tell Us About You")
                        .font(.title.bold())
                    Text("We use this to calculate your personalised calorie and macro targets.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Label("Name", systemImage: "person")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Your name", text: $viewModel.name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                }

                // Gender
                VStack(alignment: .leading, spacing: 6) {
                    Label("Biological Sex", systemImage: "person.2")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Gender", selection: $viewModel.gender) {
                        Text("Male").tag(BiologicalSex.male)
                        Text("Female").tag(BiologicalSex.female)
                    }
                    .pickerStyle(.segmented)
                }

                // Age
                VStack(alignment: .leading, spacing: 6) {
                    Label("Age", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Stepper(
                        "\(viewModel.age) years",
                        value: $viewModel.age,
                        in: 10...120
                    )
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }

                // Height
                VStack(alignment: .leading, spacing: 6) {
                    Label("Height", systemImage: "ruler")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField(
                            "e.g. 175",
                            value: $viewModel.heightCm,
                            format: .number.precision(.fractionLength(0...1))
                        )
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                }

                // Weight
                VStack(alignment: .leading, spacing: 6) {
                    Label("Weight", systemImage: "scalemass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField(
                            "e.g. 70",
                            value: $viewModel.weightKg,
                            format: .number.precision(.fractionLength(0...1))
                        )
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Preview

#Preview {
    let env = AppEnvironment.makeProductionEnvironment()
    let vm = OnboardingViewModel(
        repository: env.userProfileRepository,
        context: env.modelContainer.mainContext
    )
    return BiometricsStepView(viewModel: vm)
}

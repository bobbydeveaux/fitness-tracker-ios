import SwiftUI

// MARK: - BiometricsStepView

/// Onboarding step 2 — collects the user's biometric data.
///
/// Fields:
/// - **Name** — plain text field.
/// - **Age** — numeric stepper (18–100).
/// - **Gender** — segmented picker (male / female).
/// - **Height** — decimal text field in centimetres (100–250 cm).
/// - **Weight** — decimal text field in kilograms (30–300 kg).
///
/// All interactive controls write directly to the bound `OnboardingViewModel`.
/// The "Next" button is disabled until `viewModel.isBiometricsValid` is `true`.
struct BiometricsStepView: View {

    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // MARK: Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("About You")
                        .font(.title.bold())
                    Text("Help us personalise your TDEE and macro targets.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // MARK: Name
                LabeledContent("Name") {
                    TextField("Your name", text: $viewModel.name)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }

                Divider()

                // MARK: Gender
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gender")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Gender", selection: $viewModel.gender) {
                        Text("Male").tag(BiologicalSex.male)
                        Text("Female").tag(BiologicalSex.female)
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                // MARK: Age
                Stepper(value: $viewModel.age, in: 18...100) {
                    HStack {
                        Text("Age")
                        Spacer()
                        Text("\(viewModel.age) yrs")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Divider()

                // MARK: Height
                LabeledContent {
                    HStack(spacing: 4) {
                        TextField("170", value: $viewModel.heightCm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Text("Height")
                }

                heightWarning

                Divider()

                // MARK: Weight
                LabeledContent {
                    HStack(spacing: 4) {
                        TextField("70", value: $viewModel.weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Text("Weight")
                }

                weightWarning

                Spacer(minLength: 32)

                // MARK: Next button
                Button(action: viewModel.advance) {
                    Text("Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isBiometricsValid ? Color.accentColor : Color.secondary.opacity(0.3))
                        .foregroundStyle(viewModel.isBiometricsValid ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!viewModel.isBiometricsValid)
                .accessibilityLabel("Next")
            }
            .padding(24)
        }
    }

    // MARK: - Validation Hints

    @ViewBuilder
    private var heightWarning: some View {
        if viewModel.heightCm != 0 && !(100...250).contains(viewModel.heightCm) {
            Text("Please enter a height between 100 and 250 cm.")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var weightWarning: some View {
        if viewModel.weightKg != 0 && !(30...300).contains(viewModel.weightKg) {
            Text("Please enter a weight between 30 and 300 kg.")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Preview

#Preview {
    BiometricsStepView(viewModel: {
        let vm = OnboardingViewModel()
        vm.name = "Alex"
        vm.age = 28
        vm.gender = .female
        vm.heightCm = 165
        vm.weightKg = 62
        return vm
    }())
}

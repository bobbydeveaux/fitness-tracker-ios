import SwiftUI

// MARK: - CustomFoodFormView

/// A validated form that allows the user to create a custom `FoodItem` and
/// persist it via `NutritionRepository`.
///
/// Present this view as a sheet from the food search or meal log entry flows:
/// ```swift
/// .sheet(isPresented: $showingCustomForm) {
///     CustomFoodFormView { newItem in
///         // use the newly created FoodItem
///     }
/// }
/// ```
struct CustomFoodFormView: View {

    // MARK: - Environment

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var name: String = ""
    @State private var barcode: String = ""
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""

    @State private var isSaving: Bool = false
    @State private var validationError: String? = nil

    // MARK: - Completion

    /// Called with the newly created `FoodItem` after a successful save.
    var onSave: ((FoodItem) -> Void)?

    // MARK: - Computed Validation

    private var calories: Double? { Double(caloriesText.replacingOccurrences(of: ",", with: ".")) }
    private var protein: Double? { Double(proteinText.replacingOccurrences(of: ",", with: ".")) }
    private var carbs: Double? { Double(carbsText.replacingOccurrences(of: ",", with: ".")) }
    private var fat: Double? { Double(fatText.replacingOccurrences(of: ",", with: ".")) }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        calories != nil && calories! >= 0 &&
        protein != nil && protein! >= 0 &&
        carbs != nil && carbs! >= 0 &&
        fat != nil && fat! >= 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Basic Info
                Section("Food Details") {
                    LabeledContent {
                        TextField("e.g. Chicken Breast", text: $name)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text("Name")
                    }

                    LabeledContent {
                        TextField("Optional", text: $barcode)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    } label: {
                        Text("Barcode")
                    }
                }

                // MARK: Nutrition per 100 g
                Section {
                    MacroField(label: "Calories", unit: "kcal", text: $caloriesText)
                    MacroField(label: "Protein", unit: "g", text: $proteinText)
                    MacroField(label: "Carbohydrates", unit: "g", text: $carbsText)
                    MacroField(label: "Fat", unit: "g", text: $fatText)
                } header: {
                    Text("Nutrition per 100 g")
                } footer: {
                    if let error = validationError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveItem() }
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: - Actions

    private func saveItem() async {
        guard isFormValid,
              let kcal = calories,
              let proteinG = protein,
              let carbG = carbs,
              let fatG = fat else {
            validationError = "Please fill in all required fields with valid numbers."
            return
        }

        isSaving = true
        validationError = nil

        let item = FoodItem(
            name: name.trimmingCharacters(in: .whitespaces),
            barcode: barcode.isEmpty ? nil : barcode,
            kcalPer100g: kcal,
            proteinG: proteinG,
            carbG: carbG,
            fatG: fatG,
            isCustom: true
        )

        do {
            try await env.nutritionRepository.saveFoodItem(item)
            onSave?(item)
            dismiss()
        } catch {
            validationError = "Failed to save: \(error.localizedDescription)"
        }

        isSaving = false
    }
}

// MARK: - MacroField

private struct MacroField: View {
    let label: String
    let unit: String
    @Binding var text: String

    var body: some View {
        LabeledContent {
            HStack(spacing: 4) {
                TextField("0", text: $text)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(minWidth: 60)
                Text(unit)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        } label: {
            Text(label)
        }
    }
}

// MARK: - Preview

#Preview {
    CustomFoodFormView()
        .environment(AppEnvironment.makeProductionEnvironment())
}

import SwiftUI

// MARK: - CustomFoodFormView

/// A form that lets the user define a custom `FoodItem` by entering its name
/// and macronutrients per 100 g. On save it persists the item via the
/// repository and calls `onSave` so the caller can immediately use the new
/// food in a meal log entry.
struct CustomFoodFormView: View {

    // MARK: - Properties

    let repository: any NutritionRepository
    let onSave: (FoodItem) -> Void

    // MARK: - State

    @State private var name: String = ""
    @State private var kcalText: String = ""
    @State private var proteinText: String = ""
    @State private var carbText: String = ""
    @State private var fatText: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?

    private enum Field { case name, kcal, protein, carb, fat }

    // MARK: - Validation

    private var kcal: Double? { Double(kcalText) }
    private var protein: Double? { Double(proteinText) }
    private var carb: Double? { Double(carbText) }
    private var fat: Double? { Double(fatText) }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && kcal != nil
            && protein != nil
            && carb != nil
            && fat != nil
            && !isSaving
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section("Food Name") {
                TextField("e.g. Greek Yogurt", text: $name)
                    .focused($focusedField, equals: .name)
                    .textInputAutocapitalization(.words)
            }

            Section("Macros per 100 g") {
                macroField(
                    label: "Calories (kcal)",
                    placeholder: "e.g. 165",
                    text: $kcalText,
                    field: .kcal,
                    color: .orange
                )
                macroField(
                    label: "Protein (g)",
                    placeholder: "e.g. 31",
                    text: $proteinText,
                    field: .protein,
                    color: .red
                )
                macroField(
                    label: "Carbohydrates (g)",
                    placeholder: "e.g. 0",
                    text: $carbText,
                    field: .carb,
                    color: .blue
                )
                macroField(
                    label: "Fat (g)",
                    placeholder: "e.g. 3.6",
                    text: $fatText,
                    field: .fat,
                    color: .yellow
                )
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save Food")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle("Custom Food")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private func macroField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        color: Color
    ) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: field)
                .frame(width: 80)
        }
    }

    // MARK: - Actions

    private func save() async {
        guard let kcal, let protein, let carb, let fat else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let item = FoodItem(
            name: name.trimmingCharacters(in: .whitespaces),
            kcalPer100g: kcal,
            proteinG: protein,
            carbG: carb,
            fatG: fat,
            isCustom: true
        )
        do {
            try await repository.saveFoodItem(item)
            onSave(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

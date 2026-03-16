import SwiftUI
import SwiftData

// MARK: - MealTemplatesView

/// Lists saved meal templates and allows the user to apply any template to
/// the current meal log with a single tap.
///
/// Present this view as a sheet when the user wants to pick a template:
/// ```swift
/// .sheet(isPresented: $showingTemplates) {
///     MealTemplatesView(mealLog: currentLog) { template in
///         // template items have been added to currentLog
///     }
/// }
/// ```
struct MealTemplatesView: View {

    // MARK: - Environment & Queries

    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \MealTemplate.createdAt, order: .reverse)
    private var templates: [MealTemplate]

    // MARK: - Input

    /// The meal log that template items will be added to when the user applies a template.
    var mealLog: MealLog?

    /// Called after all items from the selected template have been appended to `mealLog`.
    var onApply: ((MealTemplate) -> Void)?

    // MARK: - State

    @State private var isApplying: Bool = false
    @State private var applyError: String? = nil

    /// Sheet for saving a new template from the given meal log.
    @State private var showingSaveSheet: Bool = false
    @State private var newTemplateName: String = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    emptyState
                } else {
                    templateList
                }
            }
            .navigationTitle("Meal Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if let mealLog, !mealLog.entries.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save Current Meal") {
                            newTemplateName = ""
                            showingSaveSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveTemplateSheet
            }
            .overlay {
                if isApplying {
                    ProgressView("Applying template…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView(
            "No Templates Yet",
            systemImage: "rectangle.stack.badge.plus",
            description: Text("Save a meal as a template to quickly re-use it later.")
        )
    }

    private var templateList: some View {
        List {
            ForEach(templates) { template in
                TemplateRow(template: template)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let mealLog else { return }
                        Task { await applyTemplate(template, to: mealLog) }
                    }
            }
            .onDelete(perform: deleteTemplates)
        }
    }

    private var saveTemplateSheet: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("e.g. Post-workout lunch", text: $newTemplateName)
                        .textInputAutocapitalization(.sentences)
                }
                if let error = applyError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Save Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingSaveSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveCurrentMealAsTemplate() }
                    }
                    .disabled(newTemplateName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func applyTemplate(_ template: MealTemplate, to log: MealLog) async {
        isApplying = true
        applyError = nil

        for item in template.items {
            guard let food = item.foodItem else { continue }
            let factor = item.servingGrams / 100.0
            let entry = MealEntry(
                servingGrams: item.servingGrams,
                kcal: food.kcalPer100g * factor,
                proteinG: food.proteinG * factor,
                carbG: food.carbG * factor,
                fatG: food.fatG * factor,
                mealLog: log,
                foodItem: food
            )
            do {
                try await env.nutritionRepository.addMealEntry(entry, to: log)
            } catch {
                applyError = "Failed to add \(food.name): \(error.localizedDescription)"
                isApplying = false
                return
            }
        }

        isApplying = false
        onApply?(template)
        dismiss()
    }

    private func saveCurrentMealAsTemplate() async {
        guard let mealLog else { return }
        let trimmedName = newTemplateName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let template = MealTemplate(name: trimmedName)
        modelContext.insert(template)

        for entry in mealLog.entries {
            let item = MealTemplateItem(
                servingGrams: entry.servingGrams,
                template: template,
                foodItem: entry.foodItem
            )
            modelContext.insert(item)
            template.items.append(item)
        }

        do {
            try modelContext.save()
            showingSaveSheet = false
        } catch {
            applyError = "Failed to save template: \(error.localizedDescription)"
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
        try? modelContext.save()
    }
}

// MARK: - TemplateRow

private struct TemplateRow: View {
    let template: MealTemplate

    private var totalKcal: Double {
        template.items.reduce(0) { sum, item in
            guard let food = item.foodItem else { return sum }
            return sum + food.kcalPer100g * (item.servingGrams / 100.0)
        }
    }

    private var itemSummary: String {
        let names = template.items.compactMap { $0.foodItem?.name }
        switch names.count {
        case 0: return "No items"
        case 1: return names[0]
        case 2: return names.joined(separator: ", ")
        default: return "\(names[0]), \(names[1]) +\(names.count - 2) more"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(template.name)
                    .font(.body.weight(.semibold))
                Spacer()
                Text(String(format: "%.0f kcal", totalKcal))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(itemSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("With templates") {
    let env = AppEnvironment.makeProductionEnvironment()
    MealTemplatesView()
        .environment(env)
        .modelContainer(env.modelContainer)
}

#Preview("Empty state") {
    let env = AppEnvironment.makeProductionEnvironment()
    MealTemplatesView()
        .environment(env)
        .modelContainer(env.modelContainer)
}

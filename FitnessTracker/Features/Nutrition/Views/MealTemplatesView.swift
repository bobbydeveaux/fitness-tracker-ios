import SwiftUI

// MARK: - MealTemplatesView

/// Shows the user's recently used and custom food items as quick-add
/// templates. Tapping a row calls `onSelect` with the selected `FoodItem`.
///
/// "Recent" items are food items that have been logged at least once
/// (i.e. they have one or more associated `MealEntry` records). Custom items
/// are those whose `isCustom` flag is `true`.
struct MealTemplatesView: View {

    // MARK: - Properties

    let repository: any NutritionRepository
    let onSelect: (FoodItem) -> Void

    // MARK: - State

    @State private var recentItems: [FoodItem] = []
    @State private var customItems: [FoodItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if recentItems.isEmpty && customItems.isEmpty {
                ContentUnavailableView(
                    "No Templates Yet",
                    systemImage: "fork.knife",
                    description: Text("Foods you log will appear here for quick access.")
                )
            } else {
                templateList
            }
        }
        .task { await loadTemplates() }
    }

    // MARK: - Subviews

    private var templateList: some View {
        List {
            if !recentItems.isEmpty {
                Section("Recently Used") {
                    ForEach(recentItems, id: \.id) { item in
                        templateRow(item)
                    }
                }
            }
            if !customItems.isEmpty {
                Section("My Foods") {
                    ForEach(customItems, id: \.id) { item in
                        templateRow(item)
                    }
                }
            }
        }
        .listStyle(.grouped)
    }

    private func templateRow(_ item: FoodItem) -> some View {
        Button {
            onSelect(item)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                HStack(spacing: 12) {
                    MacroLabel(value: item.kcalPer100g, unit: "kcal", color: .orange)
                    MacroLabel(value: item.proteinG, unit: "P", color: .red)
                    MacroLabel(value: item.carbG, unit: "C", color: .blue)
                    MacroLabel(value: item.fatG, unit: "F", color: .yellow)
                    Text("/ 100 g")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Loading

    private func loadTemplates() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let all = try await repository.fetchFoodItems()
            // Items that have been logged at least once
            recentItems = all.filter { !$0.mealEntries.isEmpty }
                             .sorted { $0.name < $1.name }
            // Custom items not already in recent
            let recentIDs = Set(recentItems.map(\.id))
            customItems = all.filter { $0.isCustom && !recentIDs.contains($0.id) }
                             .sorted { $0.name < $1.name }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

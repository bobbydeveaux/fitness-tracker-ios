import SwiftUI

// MARK: - FoodSearchFilter

/// Encapsulates the FTS prefix-match algorithm used by `FoodSearchView`.
///
/// A food item matches when every whitespace-separated token in the query is a
/// prefix of at least one whitespace-separated word in the food name
/// (case-insensitive).
///
/// Examples:
/// - query "chi br"  → matches "Chicken Breast" ✓
/// - query "chick"   → matches "Chicken Breast" ✓
/// - query "xyz"     → does not match "Chicken Breast" ✗
enum FoodSearchFilter {

    /// Returns `true` when `item.name` satisfies the FTS prefix-match for `query`.
    static func matches(item: FoodItem, query: String) -> Bool {
        let tokens = query
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .split(separator: " ")
            .map(String.init)

        guard !tokens.isEmpty else { return true }

        let words = item.name
            .lowercased()
            .split(separator: " ")
            .map(String.init)

        // All query tokens must prefix-match at least one word in the item name.
        return tokens.allSatisfy { token in
            words.contains { $0.hasPrefix(token) }
        }
    }

    /// Filters and returns only the items that match `query` using prefix-match FTS.
    static func filter(_ items: [FoodItem], query: String) -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return items }
        return items.filter { matches(item: $0, query: trimmed) }
    }
}

// MARK: - FoodSearchView

/// A searchable list of `FoodItem` records that uses FTS prefix-match to filter
/// the bundled food index in-memory as the user types.
///
/// Present this view as a sheet whenever the user needs to pick a food to log:
/// ```swift
/// .sheet(isPresented: $showingSearch) {
///     FoodSearchView { selectedFood in
///         // add selectedFood to the current meal log
///     }
/// }
/// ```
///
/// The view surfaces three distinct states:
/// - **Empty library** – the food database has no items yet; prompts the user to
///   add a custom food.
/// - **No results** – the query returned zero matches; shows the system
///   `ContentUnavailableView.search` placeholder.
/// - **Results** – a flat list where every row displays the food name, calorie
///   count per 100 g, and per-macronutrient chips.
struct FoodSearchView: View {

    // MARK: - Environment

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    // MARK: - Callback

    /// Called with the `FoodItem` the user selected. The view dismisses itself
    /// before invoking this callback.
    var onSelect: ((FoodItem) -> Void)?

    // MARK: - State

    @State private var query: String = ""
    @State private var allItems: [FoodItem] = []
    @State private var isLoading: Bool = false
    @State private var showingCustomForm: Bool = false

    // MARK: - Derived

    private var displayedItems: [FoodItem] {
        FoodSearchFilter.filter(allItems, query: query)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if allItems.isEmpty {
                    emptyLibraryState
                } else if !query.isEmpty && displayedItems.isEmpty {
                    noResultsState
                } else {
                    foodList(displayedItems)
                }
            }
            .navigationTitle("Food Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search foods…"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Custom Food") {
                        showingCustomForm = true
                    }
                }
            }
            .sheet(isPresented: $showingCustomForm) {
                CustomFoodFormView { newItem in
                    allItems.append(newItem)
                    allItems.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                }
            }
        }
        .task {
            await loadAllItems()
        }
    }

    // MARK: - Subviews

    private var emptyLibraryState: some View {
        ContentUnavailableView {
            Label("No Foods Yet", systemImage: "fork.knife")
        } description: {
            Text("Your food library is empty.\nAdd a custom food to get started.")
        } actions: {
            Button("Add Custom Food") {
                showingCustomForm = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var noResultsState: some View {
        ContentUnavailableView.search(text: query)
    }

    private func foodList(_ items: [FoodItem]) -> some View {
        List(items, id: \.id) { item in
            FoodRow(item: item)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect?(item)
                    dismiss()
                }
        }
        .listStyle(.plain)
    }

    // MARK: - Data Loading

    private func loadAllItems() async {
        isLoading = true
        do {
            allItems = try await env.nutritionRepository.fetchFoodItems()
        } catch {
            // Non-fatal: user sees the empty-library state.
        }
        isLoading = false
    }
}

// MARK: - FoodRow

private struct FoodRow: View {
    let item: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name)
                    .font(.body)
                Spacer()
                Text(String(format: "%.0f kcal", item.kcalPer100g))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            MacroChips(item: item)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - MacroChips

private struct MacroChips: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: 8) {
            MacroChip(value: item.proteinG, label: "P", color: .blue)
            MacroChip(value: item.carbG,    label: "C", color: .orange)
            MacroChip(value: item.fatG,     label: "F", color: .yellow)
            Text("per 100 g")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct MacroChip: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
            Text(String(format: "%.1f g", value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("With items") {
    let env = AppEnvironment.makeProductionEnvironment()
    FoodSearchView()
        .environment(env)
        .modelContainer(env.modelContainer)
}

#Preview("Empty library") {
    let env = AppEnvironment.makeProductionEnvironment()
    FoodSearchView()
        .environment(env)
        .modelContainer(env.modelContainer)
}

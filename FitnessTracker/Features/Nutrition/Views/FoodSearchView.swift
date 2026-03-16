import SwiftUI

// MARK: - FoodSearchView

/// Displays an inline search field and a live-updating list of `FoodItem`
/// results. Calls `onSelect` when the user taps an item.
///
/// The search is debounced by 300 ms to avoid hammering the repository on
/// every keystroke. An empty query shows all foods (up to the repository
/// fetch limit).
struct FoodSearchView: View {

    // MARK: - Properties

    let repository: any NutritionRepository
    let onSelect: (FoodItem) -> Void

    // MARK: - State

    @State private var query: String = ""
    @State private var results: [FoodItem] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if results.isEmpty && !query.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                foodList
            }
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search foods…", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: query) { _, newValue in
                    scheduleSearch(query: newValue)
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var foodList: some View {
        List(results, id: \.id) { item in
            Button {
                onSelect(item)
            } label: {
                FoodRowView(item: item)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .task { await performSearch(query: "") }
    }

    // MARK: - Search Logic

    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        searchTask = Task {
            // 300 ms debounce
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                results = try await repository.fetchFoodItems()
            } else {
                results = try await repository.searchFoodItems(query: query)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - FoodRowView

private struct FoodRowView: View {
    let item: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.body)
            HStack(spacing: 12) {
                MacroLabel(value: item.kcalPer100g, unit: "kcal", color: .orange)
                MacroLabel(value: item.proteinG, unit: "P", color: .red)
                MacroLabel(value: item.carbG, unit: "C", color: .blue)
                MacroLabel(value: item.fatG, unit: "F", color: .yellow)
                Text("per 100 g")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - MacroLabel

struct MacroLabel: View {
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(String(format: "%.0f", value))
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

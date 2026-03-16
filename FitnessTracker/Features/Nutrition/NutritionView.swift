import SwiftUI
import SwiftData

// MARK: - NutritionView

/// Main Nutrition feature screen.
///
/// Shows a `MacroSummaryBar` at the top with today's consumed vs target macros,
/// followed by a list of `MealLog` sections (Breakfast / Lunch / Dinner / Snack)
/// each containing their logged `MealEntry` rows. Tapping "+" opens
/// `MealLogEntryView` as a sheet. Swipe-to-delete removes individual entries.
struct NutritionView: View {

    // MARK: - Environment

    @Environment(AppEnvironment.self) private var env
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    // MARK: - State

    @State private var viewModel: NutritionViewModel
    @State private var showingEntrySheet: Bool = false

    // MARK: - Init

    init(repository: any NutritionRepository) {
        _viewModel = State(initialValue: NutritionViewModel(repository: repository))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Macro summary at top
                    if let profile {
                        MacroSummaryBar(
                            consumedKcal: viewModel.totalKcal,
                            consumedProteinG: viewModel.totalProteinG,
                            consumedCarbG: viewModel.totalCarbG,
                            consumedFatG: viewModel.totalFatG,
                            targetKcal: profile.tdeeKcal,
                            targetProteinG: profile.proteinTargetG,
                            targetCarbG: profile.carbTargetG,
                            targetFatG: profile.fatTargetG
                        )
                        .padding(.horizontal, 16)
                    }

                    // Meal log sections
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if viewModel.mealLogs.isEmpty {
                        emptyState
                    } else {
                        mealSections
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEntrySheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEntrySheet, onDismiss: {
                Task { await viewModel.loadTodaysLogs() }
            }) {
                MealLogEntryView(repository: env.nutritionRepository) { food, grams, mealType in
                    Task {
                        await viewModel.addEntry(
                            foodItem: food,
                            servingGrams: grams,
                            mealType: mealType
                        )
                    }
                }
            }
            .task { await viewModel.loadTodaysLogs() }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView(
            "No Meals Logged",
            systemImage: "fork.knife",
            description: Text("Tap + to add your first meal entry for today.")
        )
        .padding(.top, 40)
    }

    private var mealSections: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.mealLogs, id: \.id) { log in
                MealLogSection(
                    log: log,
                    onDeleteEntry: { entry in
                        Task { await viewModel.removeEntry(entry) }
                    },
                    onDeleteLog: {
                        Task { await viewModel.deleteMealLog(log) }
                    }
                )
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - MealLogSection

private struct MealLogSection: View {
    let log: MealLog
    let onDeleteEntry: (MealEntry) -> Void
    let onDeleteLog: () -> Void

    private var mealTypeLabel: String {
        switch log.mealType {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .dinner:    return "Dinner"
        case .snack:     return "Snack"
        }
    }

    private var sectionKcal: Double {
        log.entries.reduce(0) { $0 + $1.kcal }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Text(mealTypeLabel)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f kcal", sectionKcal))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if log.entries.isEmpty {
                Text("No items logged")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(log.entries, id: \.id) { entry in
                    EntryRow(entry: entry)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDeleteEntry(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - EntryRow

private struct EntryRow: View {
    let entry: MealEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodItem?.name ?? "Unknown Food")
                    .font(.subheadline)
                Text(String(format: "%.0f g", entry.servingGrams))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f kcal", entry.kcal))
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Text(String(format: "P%.0f  C%.0f  F%.0f",
                            entry.proteinG,
                            entry.carbG,
                            entry.fatG))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NutritionView(repository: PreviewNutritionRepository())
        .environment(AppEnvironment.makeProductionEnvironment())
}

// MARK: - PreviewNutritionRepository

private final class PreviewNutritionRepository: NutritionRepository, @unchecked Sendable {
    func fetchFoodItems() async throws -> [FoodItem] { [] }
    func fetchFoodItem(byID id: UUID) async throws -> FoodItem? { nil }
    func searchFoodItems(query: String) async throws -> [FoodItem] { [] }
    func saveFoodItem(_ item: FoodItem) async throws {}
    func deleteFoodItem(_ item: FoodItem) async throws {}
    func fetchMealLogs(for date: Date) async throws -> [MealLog] { [] }
    func fetchMealLogs(from startDate: Date, to endDate: Date) async throws -> [MealLog] { [] }
    func saveMealLog(_ log: MealLog) async throws {}
    func deleteMealLog(_ log: MealLog) async throws {}
    func addMealEntry(_ entry: MealEntry, to log: MealLog) async throws {}
    func removeMealEntry(_ entry: MealEntry) async throws {}
}

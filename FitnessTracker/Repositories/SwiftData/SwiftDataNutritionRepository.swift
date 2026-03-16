import Foundation
import SwiftData

/// SwiftData-backed implementation of NutritionRepository.
/// Uses @ModelActor to ensure all SwiftData operations run on a background serial executor,
/// keeping the ModelContext off the main thread.
@ModelActor
public actor SwiftDataNutritionRepository: NutritionRepository {

    // MARK: - FoodItem

    public func fetchFoodItems() async throws -> [FoodItem] {
        var descriptor = FetchDescriptor<FoodItem>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        descriptor.fetchLimit = 1000
        return try modelContext.fetch(descriptor)
    }

    public func fetchFoodItem(byID id: UUID) async throws -> FoodItem? {
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    public func searchFoodItems(query: String) async throws -> [FoodItem] {
        let lowercased = query.lowercased()
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.name.localizedStandardContains(lowercased) },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func saveFoodItem(_ item: FoodItem) async throws {
        if item.modelContext == nil {
            modelContext.insert(item)
        }
        try modelContext.save()
    }

    public func deleteFoodItem(_ item: FoodItem) async throws {
        modelContext.delete(item)
        try modelContext.save()
    }

    // MARK: - MealLog

    public func fetchMealLogs(for date: Date) async throws -> [MealLog] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        let descriptor = FetchDescriptor<MealLog>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchMealLogs(from startDate: Date, to endDate: Date) async throws -> [MealLog] {
        let descriptor = FetchDescriptor<MealLog>(
            predicate: #Predicate { $0.date >= startDate && $0.date <= endDate },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func saveMealLog(_ log: MealLog) async throws {
        if log.modelContext == nil {
            modelContext.insert(log)
        }
        try modelContext.save()
    }

    public func deleteMealLog(_ log: MealLog) async throws {
        modelContext.delete(log)
        try modelContext.save()
    }

    // MARK: - MealEntry

    public func addMealEntry(_ entry: MealEntry, to log: MealLog) async throws {
        if entry.modelContext == nil {
            modelContext.insert(entry)
        }
        log.entries.append(entry)
        entry.mealLog = log
        try modelContext.save()
    }

    public func removeMealEntry(_ entry: MealEntry) async throws {
        modelContext.delete(entry)
        try modelContext.save()
    }
}

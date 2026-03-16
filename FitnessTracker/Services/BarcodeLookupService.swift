import Foundation

// MARK: - BarcodeLookupService

/// Resolves a product barcode to a `FoodItem` using the local `NutritionRepository`.
///
/// Look-up order:
/// 1. Search the local SwiftData store for a `FoodItem` whose `barcode` property matches.
/// 2. Return `nil` if no match is found (the caller should then fall back to
///    the custom-food form or prompt the user to add the item manually).
///
/// A future version may add a remote Open Food Facts / USDA API call after step 1.
actor BarcodeLookupService {

    // MARK: - Init

    init() {}

    // MARK: - Public API

    /// Resolves `barcode` to a `FoodItem` in the given repository.
    ///
    /// - Parameters:
    ///   - barcode: The raw string value returned by the barcode scanner.
    ///   - repository: The nutrition repository to query.
    /// - Returns: The matching `FoodItem`, or `nil` if not found locally.
    func lookup(barcode: String, in repository: any NutritionRepository) async throws -> FoodItem? {
        let allItems = try await repository.fetchFoodItems()
        return allItems.first { $0.barcode == barcode }
    }
}

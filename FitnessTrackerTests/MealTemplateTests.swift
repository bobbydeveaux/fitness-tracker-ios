import XCTest
import SwiftData
@testable import FitnessTracker

/// Validates MealTemplate and MealTemplateItem SwiftData models and their
/// cascade delete behaviour.
final class MealTemplateTests: XCTestCase {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        try AppSchema.makeContainer(inMemory: true)
    }

    // MARK: - Insert & Fetch

    func testInsertAndFetchMealTemplate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let template = MealTemplate(name: "Post-Workout Lunch")
        context.insert(template)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MealTemplate>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Post-Workout Lunch")
    }

    func testMealTemplateWithItems() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let food = FoodItem(
            name: "Chicken Breast",
            kcalPer100g: 165.0,
            proteinG: 31.0,
            carbG: 0.0,
            fatG: 3.6,
            isCustom: false
        )
        context.insert(food)

        let template = MealTemplate(name: "High-Protein Lunch")
        context.insert(template)

        let item = MealTemplateItem(servingGrams: 200.0, template: template, foodItem: food)
        context.insert(item)
        template.items.append(item)

        try context.save()

        let templates = try context.fetch(FetchDescriptor<MealTemplate>())
        XCTAssertEqual(templates.count, 1)
        XCTAssertEqual(templates.first?.items.count, 1)
        XCTAssertEqual(templates.first?.items.first?.servingGrams, 200.0, accuracy: 0.01)
        XCTAssertEqual(templates.first?.items.first?.foodItem?.name, "Chicken Breast")
    }

    // MARK: - Cascade Delete

    func testCascadeDeleteTemplateRemovesItems() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let template = MealTemplate(name: "Breakfast Combo")
        context.insert(template)

        let item1 = MealTemplateItem(servingGrams: 100.0, template: template)
        let item2 = MealTemplateItem(servingGrams: 50.0, template: template)
        context.insert(item1)
        context.insert(item2)
        template.items.append(contentsOf: [item1, item2])

        try context.save()

        let itemsBefore = try context.fetch(FetchDescriptor<MealTemplateItem>())
        XCTAssertEqual(itemsBefore.count, 2)

        context.delete(template)
        try context.save()

        let itemsAfter = try context.fetch(FetchDescriptor<MealTemplateItem>())
        XCTAssertEqual(itemsAfter.count, 0,
                       "MealTemplateItems should be cascade deleted with their MealTemplate")
    }

    // MARK: - AppSchema Registration

    func testAppSchemaIncludesMealTemplateTypes() throws {
        let types = AppSchema.models.map { ObjectIdentifier($0) }
        XCTAssertTrue(
            types.contains(ObjectIdentifier(MealTemplate.self)),
            "AppSchema should register MealTemplate"
        )
        XCTAssertTrue(
            types.contains(ObjectIdentifier(MealTemplateItem.self)),
            "AppSchema should register MealTemplateItem"
        )
    }

    // MARK: - FoodItem isCustom Flag

    func testCustomFoodItemIsMarkedCorrectly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let customFood = FoodItem(
            name: "My Protein Bar",
            kcalPer100g: 380.0,
            proteinG: 30.0,
            carbG: 35.0,
            fatG: 10.0,
            isCustom: true
        )
        context.insert(customFood)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched.first?.isCustom == true,
                      "User-created food items must have isCustom = true")
    }
}

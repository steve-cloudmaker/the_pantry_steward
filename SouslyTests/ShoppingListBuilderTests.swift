import CoreData
import XCTest
@testable import Sously

@MainActor
final class ShoppingListBuilderTests: XCTestCase {
    func testLowStockGaps() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.viewContext
        let pantry = PantryRepository(context: context)
        let shopping = ShoppingRepository(context: context)
        let recipes = RecipeRepository(context: context)
        let mealPlans = MealPlanRepository(context: context)
        let builder = ShoppingListBuilderService(
            pantry: pantry,
            shopping: shopping,
            recipeRepository: recipes,
            mealPlanRepository: mealPlans
        )

        _ = try pantry.create(name: "Butter", quantity: 0.5, unit: "stick", lowStockThreshold: 2)
        let gaps = try builder.gapsForLowStock()
        XCTAssertEqual(gaps.count, 1)
        XCTAssertEqual(gaps.first?.name, "Butter")
    }
}

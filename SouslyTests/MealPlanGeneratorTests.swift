import CoreData
import XCTest
@testable import Sously

@MainActor
final class MealPlanGeneratorTests: XCTestCase {
    func testGeneratesSuggestionsFromSeedData() throws {
        SeedDataService.resetSeedFlag()
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.viewContext
        SeedDataService.seedIfNeeded(context: context)

        let recipes = RecipeRepository(context: context)
        let pantry = PantryRepository(context: context)
        let mealPlans = MealPlanRepository(context: context)
        let matcher = RecipeMatchingService(pantry: pantry)
        let generator = MealPlanGeneratorService(
            recipeRepository: recipes,
            recipeMatcher: matcher,
            mealPlanRepository: mealPlans
        )

        var options = MealPlanGenerationOptions()
        options.days = 7
        options.minimumMatchScore = 0.35
        let suggestions = try generator.generateSuggestions(options: options)
        XCTAssertFalse(suggestions.isEmpty)
        // Capped by number of matchable seed recipes (2 in default seed data).
        XCTAssertLessThanOrEqual(suggestions.count, 2)
    }
}

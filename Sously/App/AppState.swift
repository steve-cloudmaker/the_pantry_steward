import Combine
import CoreData
import Foundation

@MainActor
final class AppState: ObservableObject {
    let persistence: PersistenceController

    lazy var pantryRepository: PantryRepository = PantryRepository(context: persistence.viewContext)
    lazy var shoppingRepository: ShoppingRepository = ShoppingRepository(context: persistence.viewContext)
    lazy var recipeRepository: RecipeRepository = RecipeRepository(context: persistence.viewContext)
    lazy var mealPlanRepository: MealPlanRepository = MealPlanRepository(context: persistence.viewContext)
    lazy var categoryRepository: CategoryRepository = CategoryRepository(context: persistence.viewContext)
    lazy var tagRepository: TagRepository = TagRepository(context: persistence.viewContext)

    lazy var recipeMatcher: RecipeMatchingService = RecipeMatchingService(pantry: pantryRepository)
    lazy var mealPlanGenerator: MealPlanGeneratorService = MealPlanGeneratorService(
        recipeRepository: recipeRepository,
        recipeMatcher: recipeMatcher,
        mealPlanRepository: mealPlanRepository
    )
    lazy var shoppingListBuilder: ShoppingListBuilderService = ShoppingListBuilderService(
        pantry: pantryRepository,
        shopping: shoppingRepository,
        recipeRepository: recipeRepository,
        mealPlanRepository: mealPlanRepository
    )
    lazy var recipeImporter: RecipeImportService = RecipeImportService()
    lazy var inventoryAdjuster: InventoryAdjustmentService = InventoryAdjustmentService(pantry: pantryRepository)

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        SeedDataService.seedIfNeeded(context: persistence.viewContext)
    }
}

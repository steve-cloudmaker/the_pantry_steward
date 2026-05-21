import Foundation

@MainActor
final class InventoryAdjustmentService {
    private let pantry: PantryRepository

    init(pantry: PantryRepository) {
        self.pantry = pantry
    }

    /// Deducts recipe ingredients from pantry when a meal is marked eaten.
    func applyMealEaten(_ meal: PlannedMeal) throws {
        guard meal.isEaten, let recipe = meal.recipe else { return }
        let scale = Double(meal.servings) / max(1, Double(recipe.servings))
        let items = try pantry.fetchAll()

        for ingredient in recipe.ingredientList where !ingredient.isOptional {
            let needed = ingredient.quantity * scale
            if let match = items.first(where: {
                IngredientNormalizer.matches(pantryName: $0.safeName, recipeName: ingredient.safeName)
            }) {
                try pantry.adjustQuantity(match, by: -needed)
            }
        }
    }

    func markMealEaten(_ meal: PlannedMeal, mealPlanRepository: MealPlanRepository) throws {
        try mealPlanRepository.markEaten(meal, eaten: true)
        try applyMealEaten(meal)
    }
}

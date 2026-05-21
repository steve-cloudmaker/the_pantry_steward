import Foundation

struct ShoppingListIngredientGap: Identifiable {
    let id: UUID
    let name: String
    let quantity: Double
    let unit: String
    let reason: String
    let sourceRecipeID: UUID?
}

@MainActor
final class ShoppingListBuilderService {
    private let pantry: PantryRepository
    private let shopping: ShoppingRepository
    private let recipeRepository: RecipeRepository
    private let mealPlanRepository: MealPlanRepository
    private let recipeMatcher: RecipeMatchingService

    init(
        pantry: PantryRepository,
        shopping: ShoppingRepository,
        recipeRepository: RecipeRepository,
        mealPlanRepository: MealPlanRepository
    ) {
        self.pantry = pantry
        self.shopping = shopping
        self.recipeRepository = recipeRepository
        self.mealPlanRepository = mealPlanRepository
        self.recipeMatcher = RecipeMatchingService(pantry: pantry)
    }

    func gapsForLowStock() throws -> [ShoppingListIngredientGap] {
        try pantry.lowStockItems().map { item in
            let needed = max(0, item.lowStockThreshold - item.quantity + 1)
            return ShoppingListIngredientGap(
                id: UUID(),
                name: item.safeName,
                quantity: needed,
                unit: item.safeUnit,
                reason: "Low stock",
                sourceRecipeID: nil
            )
        }
    }

    func gapsForUpcomingMeals(withinDays days: Int = 7) throws -> [ShoppingListIngredientGap] {
        let meals = try mealPlanRepository.upcomingMeals(withinDays: days)
        var gaps: [ShoppingListIngredientGap] = []
        let pantryItems = try pantry.fetchAll()

        for meal in meals {
            guard let recipe = meal.recipe else { continue }
            let scale = Double(meal.servings) / max(1, Double(recipe.servings))
            for ingredient in recipe.ingredientList where !ingredient.isOptional {
                let scaledQty = ingredient.quantity * scale
                if !pantryHasSufficient(ingredient.safeName, quantity: scaledQty, in: pantryItems) {
                    gaps.append(ShoppingListIngredientGap(
                        id: UUID(),
                        name: ingredient.safeName,
                        quantity: scaledQty,
                        unit: ingredient.safeUnit,
                        reason: "Meal plan: \(recipe.safeName)",
                        sourceRecipeID: recipe.id
                    ))
                }
            }
        }
        return mergeGaps(gaps)
    }

    func gapsForRecipe(_ recipe: Recipe, servings: Int16? = nil) throws -> [ShoppingListIngredientGap] {
        let targetServings = servings ?? recipe.servings
        let scale = Double(targetServings) / max(1, Double(recipe.servings))
        let pantryItems = try pantry.fetchAll()
        var gaps: [ShoppingListIngredientGap] = []

        for ingredient in recipe.ingredientList where !ingredient.isOptional {
            let scaledQty = ingredient.quantity * scale
            if !pantryHasSufficient(ingredient.safeName, quantity: scaledQty, in: pantryItems) {
                gaps.append(ShoppingListIngredientGap(
                    id: UUID(),
                    name: ingredient.safeName,
                    quantity: scaledQty,
                    unit: ingredient.safeUnit,
                    reason: "Recipe: \(recipe.safeName)",
                    sourceRecipeID: recipe.id
                ))
            }
        }
        return gaps
    }

    @discardableResult
    func populateList(
        _ list: ShoppingList,
        includeLowStock: Bool = true,
        includeUpcomingMeals: Bool = true
    ) throws -> ShoppingList {
        var allGaps: [ShoppingListIngredientGap] = []
        if includeLowStock {
            allGaps.append(contentsOf: try gapsForLowStock())
        }
        if includeUpcomingMeals {
            allGaps.append(contentsOf: try gapsForUpcomingMeals())
        }
        allGaps = mergeGaps(allGaps)

        for gap in allGaps {
            _ = try shopping.addItem(
                to: list,
                name: gap.name,
                quantity: gap.quantity,
                unit: gap.unit,
                notes: gap.reason,
                sourceRecipeID: gap.sourceRecipeID
            )
        }
        return list
    }

    @discardableResult
    func addRecipeIngredientsToList(
        _ list: ShoppingList,
        recipe: Recipe,
        servings: Int16? = nil,
        onlyMissing: Bool = true
    ) throws -> ShoppingList {
        let gaps = try gapsForRecipe(recipe, servings: servings)
        let toAdd = onlyMissing ? gaps : recipe.ingredientList.map { ingredient in
            ShoppingListIngredientGap(
                id: UUID(),
                name: ingredient.safeName,
                quantity: ingredient.quantity,
                unit: ingredient.safeUnit,
                reason: "Recipe: \(recipe.safeName)",
                sourceRecipeID: recipe.id
            )
        }

        for gap in toAdd {
            _ = try shopping.addItem(
                to: list,
                name: gap.name,
                quantity: gap.quantity,
                unit: gap.unit,
                notes: gap.reason,
                sourceRecipeID: gap.sourceRecipeID
            )
        }
        return list
    }

    private func pantryHasSufficient(_ name: String, quantity: Double, in items: [PantryItem]) -> Bool {
        items.contains { item in
            IngredientNormalizer.matches(pantryName: item.safeName, recipeName: name) && item.quantity >= quantity
        }
    }

    private func pantryHas(_ name: String, in items: [PantryItem]) -> Bool {
        items.contains { item in
            IngredientNormalizer.matches(pantryName: item.safeName, recipeName: name) && item.quantity > 0
        }
    }

    private func mergeGaps(_ gaps: [ShoppingListIngredientGap]) -> [ShoppingListIngredientGap] {
        var merged: [String: ShoppingListIngredientGap] = [:]
        for gap in gaps {
            let key = IngredientNormalizer.normalize(gap.name)
            if var existing = merged[key] {
                existing = ShoppingListIngredientGap(
                    id: existing.id,
                    name: existing.name,
                    quantity: existing.quantity + gap.quantity,
                    unit: existing.unit,
                    reason: existing.reason,
                    sourceRecipeID: existing.sourceRecipeID ?? gap.sourceRecipeID
                )
                merged[key] = existing
            } else {
                merged[key] = gap
            }
        }
        return merged.values.sorted { $0.name < $1.name }
    }
}

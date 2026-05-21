import CoreData
import Foundation

struct RecipeSearchCriteria {
    var query: String = ""
    var favoritesOnly: Bool = false
    var tag: Tag?
}

@MainActor
final class RecipeRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAll(criteria: RecipeSearchCriteria = RecipeSearchCriteria()) throws -> [Recipe] {
        let request = Recipe.fetchRequest()
        var predicates: [NSPredicate] = []
        let trimmed = criteria.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            predicates.append(NSPredicate(
                format: "name CONTAINS[cd] %@ OR summary CONTAINS[cd] %@ OR notes CONTAINS[cd] %@ OR ANY tags.name CONTAINS[cd] %@",
                trimmed, trimmed, trimmed, trimmed
            ))
        }
        if criteria.favoritesOnly {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }
        if let tag = criteria.tag {
            predicates.append(NSPredicate(format: "ANY tags == %@", tag))
        }
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Recipe.name, ascending: true)]
        return try context.fetch(request)
    }

    func fetch(id: UUID) throws -> Recipe? {
        let request = Recipe.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    @discardableResult
    func create(
        name: String,
        summary: String? = nil,
        servings: Int16 = 4,
        prepTimeMinutes: Int32 = 0,
        cookTimeMinutes: Int32 = 0,
        sourceURL: String? = nil,
        notes: String? = nil,
        photoData: Data? = nil,
        isFavorite: Bool = false,
        ingredients: [(name: String, quantity: Double, unit: String, isOptional: Bool)] = [],
        steps: [String] = [],
        tags: [Tag] = []
    ) throws -> Recipe {
        let recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.name = name
        recipe.summary = summary
        recipe.servings = servings
        recipe.prepTimeMinutes = prepTimeMinutes
        recipe.cookTimeMinutes = cookTimeMinutes
        recipe.sourceURL = sourceURL
        recipe.notes = notes
        recipe.photoData = photoData
        recipe.isFavorite = isFavorite
        recipe.tags = NSSet(array: tags)
        let now = Date()
        recipe.createdAt = now
        recipe.updatedAt = now

        for (index, ingredient) in ingredients.enumerated() {
            let row = RecipeIngredient(context: context)
            row.id = UUID()
            row.name = ingredient.name
            row.quantity = ingredient.quantity
            row.unit = ingredient.unit
            row.isOptional = ingredient.isOptional
            row.sortOrder = Int16(index)
            row.recipe = recipe
        }

        for (index, step) in steps.enumerated() {
            let row = RecipeStep(context: context)
            row.id = UUID()
            row.instruction = step
            row.sortOrder = Int16(index)
            row.recipe = recipe
        }

        try context.save()
        return recipe
    }

    func update(_ recipe: Recipe) throws {
        recipe.updatedAt = Date()
        try context.save()
    }

    func delete(_ recipe: Recipe) throws {
        context.delete(recipe)
        try context.save()
    }

    func replaceIngredients(
        on recipe: Recipe,
        with ingredients: [(name: String, quantity: Double, unit: String, isOptional: Bool)]
    ) throws {
        if let existing = recipe.ingredients as? Set<RecipeIngredient> {
            existing.forEach { context.delete($0) }
        }
        for (index, ingredient) in ingredients.enumerated() {
            let row = RecipeIngredient(context: context)
            row.id = UUID()
            row.name = ingredient.name
            row.quantity = ingredient.quantity
            row.unit = ingredient.unit
            row.isOptional = ingredient.isOptional
            row.sortOrder = Int16(index)
            row.recipe = recipe
        }
        recipe.updatedAt = Date()
        try context.save()
    }

    func replaceSteps(on recipe: Recipe, with steps: [String]) throws {
        if let existing = recipe.steps as? Set<RecipeStep> {
            existing.forEach { context.delete($0) }
        }
        for (index, step) in steps.enumerated() {
            let row = RecipeStep(context: context)
            row.id = UUID()
            row.instruction = step
            row.sortOrder = Int16(index)
            row.recipe = recipe
        }
        recipe.updatedAt = Date()
        try context.save()
    }
}

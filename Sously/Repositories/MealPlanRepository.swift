import CoreData
import Foundation

@MainActor
final class MealPlanRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchPlans() throws -> [MealPlan] {
        let request = MealPlan.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \MealPlan.startDate, ascending: false)
        ]
        return try context.fetch(request)
    }

    func fetchPlan(id: UUID) throws -> MealPlan? {
        let request = MealPlan.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    @discardableResult
    func createPlan(
        name: String,
        startDate: Date,
        endDate: Date,
        notes: String? = nil
    ) throws -> MealPlan {
        let plan = MealPlan(context: context)
        plan.id = UUID()
        plan.name = name
        plan.startDate = startDate
        plan.endDate = endDate
        plan.notes = notes
        let now = Date()
        plan.createdAt = now
        plan.updatedAt = now
        try context.save()
        return plan
    }

    @discardableResult
    func addMeal(
        to plan: MealPlan,
        recipe: Recipe,
        date: Date,
        mealType: MealType,
        servings: Int16 = 4,
        notes: String? = nil
    ) throws -> PlannedMeal {
        let meal = PlannedMeal(context: context)
        meal.id = UUID()
        meal.date = date
        meal.mealType = mealType.rawValue
        meal.servings = servings
        meal.notes = notes
        meal.isEaten = false
        meal.recipe = recipe
        meal.mealPlan = plan
        plan.updatedAt = Date()
        try context.save()
        return meal
    }

    func markEaten(_ meal: PlannedMeal, eaten: Bool = true) throws {
        meal.isEaten = eaten
        meal.mealPlan?.updatedAt = Date()
        try context.save()
    }

    func upcomingMeals(withinDays days: Int = 7) throws -> [PlannedMeal] {
        let request = PlannedMeal.fetchRequest()
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@ AND isEaten == NO",
            start as NSDate, end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PlannedMeal.date, ascending: true)]
        return try context.fetch(request)
    }

    func deletePlan(_ plan: MealPlan) throws {
        context.delete(plan)
        try context.save()
    }
}

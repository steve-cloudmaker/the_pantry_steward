import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum MealPlanExportService {
    static func plainText(for plan: MealPlan) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        var lines: [String] = [
            plan.safeName,
            "\(formatter.string(from: plan.startDate ?? Date())) – \(formatter.string(from: plan.endDate ?? Date()))",
            ""
        ]
        let meals = ((plan.meals as? Set<PlannedMeal>) ?? []).sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        for meal in meals {
            let recipeName = meal.recipe?.safeName ?? "—"
            let type = meal.mealTypeEnum.displayName
            lines.append("\(formatter.string(from: meal.date ?? Date())) · \(type): \(recipeName) (\(meal.servings) servings)")
            if meal.isEaten { lines.append("  ✓ Eaten") }
            if let notes = meal.notes, !notes.isEmpty { lines.append("  Notes: \(notes)") }
        }
        if let notes = plan.notes, !notes.isEmpty {
            lines.append("")
            lines.append(notes)
        }
        return lines.joined(separator: "\n")
    }

    #if canImport(UIKit)
    static func printPlan(_ plan: MealPlan) {
        let text = plainText(for: plan)
        let formatter = UISimpleTextPrintFormatter(text: text)
        let controller = UIPrintInteractionController.shared
        controller.printFormatter = formatter
        controller.present(animated: true)
    }
    #endif
}

import Foundation

// MARK: - Non-optional accessors for Core Data strings

extension PantryItem {
    var safeName: String { name ?? "" }
    var safeUnit: String { unit ?? "each" }
}

extension Recipe {
    var safeName: String { name ?? "" }
}

extension RecipeIngredient {
    var safeName: String { name ?? "" }
    var safeUnit: String { unit ?? "each" }
}

extension RecipeStep {
    var safeInstruction: String { instruction ?? "" }
}

extension ShoppingList {
    var safeName: String { name ?? "" }
}

extension ShoppingListItem {
    var safeName: String { name ?? "" }
    var safeUnit: String { unit ?? "each" }
}

extension Category {
    var safeName: String { name ?? "" }
}

extension SubCategory {
    var safeName: String { name ?? "" }
}

extension MealPlan {
    var safeName: String { name ?? "" }
}

extension Tag {
    var safeName: String { name ?? "" }
}

// MARK: - Domain helpers

extension PantryItem {
    var stockStatus: StockStatus {
        if quantity <= 0 { return .out }
        if quantity <= lowStockThreshold { return .low }
        return .inStock
    }

    var expirationStatus: ExpirationStatus {
        let reference = expirationDate ?? bestBeforeDate
        guard let reference else { return .fresh }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfReference = calendar.startOfDay(for: reference)
        if startOfReference < startOfToday { return .expired }
        if let soon = calendar.date(byAdding: .day, value: 7, to: startOfToday),
           startOfReference <= soon {
            return .expiringSoon
        }
        return .fresh
    }

    var tagNames: [String] {
        (tags as? Set<Tag>)?
            .map(\.safeName)
            .filter { !$0.isEmpty }
            .sorted() ?? []
    }

    var displayQuantity: String {
        QuantityFormatter.format(quantity: quantity, unit: unit ?? "each")
    }
}

extension Recipe {
    var ingredientList: [RecipeIngredient] {
        ((ingredients as? Set<RecipeIngredient>) ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var stepList: [RecipeStep] {
        ((steps as? Set<RecipeStep>) ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var totalTimeMinutes: Int {
        Int(prepTimeMinutes) + Int(cookTimeMinutes)
    }
}

extension ShoppingList {
    var itemList: [ShoppingListItem] {
        ((items as? Set<ShoppingListItem>) ?? [])
            .sorted { lhs, rhs in
                if lhs.isChecked != rhs.isChecked { return !lhs.isChecked }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    var uncheckedTotal: Double {
        itemList
            .filter { !$0.isChecked }
            .reduce(0) { $0 + ($1.price) }
    }

    var checkedTotal: Double {
        itemList
            .filter(\.isChecked)
            .reduce(0) { $0 + ($1.price) }
    }

    var grandTotal: Double {
        itemList.reduce(0) { $0 + ($1.price) }
    }
}

extension PlannedMeal {
    var mealTypeEnum: MealType {
        MealType(rawValue: mealType ?? MealType.dinner.rawValue) ?? .dinner
    }
}

extension Tag {
    static func normalizedName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if name.hasPrefix("#") {
            name = String(name.dropFirst())
        }
        return name
    }

    var displayName: String { "#\(safeName)" }
}

import Foundation

enum MealType: String, CaseIterable, Identifiable, Codable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: "sun.horizon"
        case .lunch: "sun.max"
        case .dinner: "moon.stars"
        case .snack: "carrot"
        }
    }
}

enum PantrySort: String, CaseIterable, Identifiable {
    case name
    case expiration
    case quantity
    case priority
    case recentlyUpdated

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name: "Name"
        case .expiration: "Expiration"
        case .quantity: "Quantity"
        case .priority: "Priority"
        case .recentlyUpdated: "Recently Updated"
        }
    }
}

enum StockStatus {
    case inStock
    case low
    case out

    var displayName: String {
        switch self {
        case .inStock: "In stock"
        case .low: "Low"
        case .out: "Out"
        }
    }
}

enum ExpirationStatus {
    case fresh
    case expiringSoon
    case expired

    var displayName: String {
        switch self {
        case .fresh: "Fresh"
        case .expiringSoon: "Expiring soon"
        case .expired: "Expired"
        }
    }
}

enum RecipeMatchSort: String, CaseIterable, Identifiable {
    case matchScore
    case name
    case cookTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .matchScore: "Best match"
        case .name: "Name"
        case .cookTime: "Cook time"
        }
    }
}

import Foundation

/// Normalizes ingredient names for pantry ↔ recipe matching.
enum IngredientNormalizer {
    private static let stopWords: Set<String> = [
        "fresh", "dried", "chopped", "diced", "minced", "sliced", "large", "small",
        "medium", "organic", "raw", "cooked", "ground", "whole", "boneless", "skinless"
    ]

    static func normalize(_ name: String) -> String {
        var tokens = name
            .lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .map(String.init)

        if let last = tokens.last, ["optional", "to", "taste"].contains(last) {
            tokens.removeLast()
        }

        tokens = tokens.filter { !stopWords.contains($0) && !$0.isEmpty }
        return tokens.joined(separator: " ")
    }

    static func matches(pantryName: String, recipeName: String) -> Bool {
        let a = normalize(pantryName)
        let b = normalize(recipeName)
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a == b { return true }
        if a.contains(b) || b.contains(a) { return true }

        let aTokens = Set(a.split(separator: " ").map(String.init))
        let bTokens = Set(b.split(separator: " ").map(String.init))
        let overlap = aTokens.intersection(bTokens)
        let threshold = max(1, min(aTokens.count, bTokens.count) - 1)
        return overlap.count >= threshold
    }
}

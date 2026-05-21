import Foundation

struct ImportedRecipeDraft {
    var name: String
    var summary: String?
    var servings: Int16 = 4
    var prepTimeMinutes: Int32 = 0
    var cookTimeMinutes: Int32 = 0
    var sourceURL: String?
    var ingredients: [(name: String, quantity: Double, unit: String, isOptional: Bool)]
    var steps: [String]
}

enum RecipeImportError: LocalizedError {
    case invalidURL
    case networkFailure(Error)
    case parseFailure
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The URL is not valid."
        case .networkFailure(let error): "Could not load recipe: \(error.localizedDescription)"
        case .parseFailure: "Could not extract recipe data from this page."
        case .unsupportedFormat: "This page format is not supported yet."
        }
    }
}

/// Imports recipes from URLs using JSON-LD Recipe schema and HTML fallbacks.
final class RecipeImportService: @unchecked Sendable {
    func importFromURL(_ urlString: String) async throws -> ImportedRecipeDraft {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw RecipeImportError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw RecipeImportError.parseFailure
        }

        if let jsonLD = JSONLDRecipeParser.parse(html: html) {
            return jsonLD
        }
        if let microdata = MicrodataRecipeParser.parse(html: html) {
            return microdata
        }
        throw RecipeImportError.parseFailure
    }
}

// MARK: - JSON-LD

enum JSONLDRecipeParser {
    static func parse(html: String) -> ImportedRecipeDraft? {
        let scripts = extractJSONLDBlocks(from: html)
        for script in scripts {
            if let draft = parseRecipeJSON(script) {
                return draft
            }
        }
        return nil
    }

    private static func extractJSONLDBlocks(from html: String) -> [String] {
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let contentRange = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[contentRange])
        }
    }

    private static func parseRecipeJSON(_ json: String) -> ImportedRecipeDraft? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else { return nil }

        if let dict = object as? [String: Any] {
            return recipeFrom(dict: dict)
        }
        if let array = object as? [[String: Any]] {
            for dict in array {
                if let recipe = recipeFrom(dict: dict) { return recipe }
            }
        }
        if let graph = (object as? [String: Any])?["@graph"] as? [[String: Any]] {
            for dict in graph {
                if let recipe = recipeFrom(dict: dict) { return recipe }
            }
        }
        return nil
    }

    private static func recipeFrom(dict: [String: Any]) -> ImportedRecipeDraft? {
        let type = (dict["@type"] as? String) ?? (dict["@type"] as? [String])?.first ?? ""
        guard type.lowercased().contains("recipe") else { return nil }

        let name = dict["name"] as? String ?? "Imported Recipe"
        let summary = dict["description"] as? String
        let yieldValue = dict["recipeYield"]
        let servings = parseServings(yieldValue)
        let prep = parseDuration(dict["prepTime"] as? String)
        let cook = parseDuration(dict["cookTime"] as? String)

        var ingredients: [(String, Double, String, Bool)] = []
        if let ingredientList = dict["recipeIngredient"] as? [Any] {
            for item in ingredientList {
                if let line = item as? String {
                    let parsed = IngredientLineParser.parse(line)
                    ingredients.append((parsed.name, parsed.quantity, parsed.unit, parsed.isOptional))
                }
            }
        }

        var steps: [String] = []
        if let instructions = dict["recipeInstructions"] as? [Any] {
            for (index, item) in instructions.enumerated() {
                if let text = item as? String {
                    steps.append(text)
                } else if let stepDict = item as? [String: Any],
                          let text = stepDict["text"] as? String {
                    steps.append(text)
                } else if let text = (item as? [String: Any])?["name"] as? String {
                    steps.append(text)
                } else {
                    steps.append("Step \(index + 1)")
                }
            }
        } else if let single = dict["recipeInstructions"] as? String {
            steps = single
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return ImportedRecipeDraft(
            name: name,
            summary: summary,
            servings: servings,
            prepTimeMinutes: prep,
            cookTimeMinutes: cook,
            sourceURL: dict["url"] as? String,
            ingredients: ingredients,
            steps: steps
        )
    }

    private static func parseServings(_ value: Any?) -> Int16 {
        if let int = value as? Int { return Int16(int) }
        if let string = value as? String, let int = Int(string.filter(\.isNumber)) {
            return Int16(int)
        }
        if let array = value as? [Any], let first = array.first {
            return parseServings(first)
        }
        return 4
    }

    private static func parseDuration(_ iso8601: String?) -> Int32 {
        guard let iso8601 else { return 0 }
        // PT30M, PT1H30M
        var minutes: Int32 = 0
        if let hRange = iso8601.range(of: #"(\d+)H"#, options: .regularExpression) {
            let hours = iso8601[hRange].filter(\.isNumber)
            minutes += (Int32(hours) ?? 0) * 60
        }
        if let mRange = iso8601.range(of: #"(\d+)M"#, options: .regularExpression) {
            let mins = iso8601[mRange].filter(\.isNumber)
            minutes += Int32(mins) ?? 0
        }
        return minutes
    }
}

// MARK: - Microdata fallback

enum MicrodataRecipeParser {
    static func parse(html: String) -> ImportedRecipeDraft? {
        guard html.localizedCaseInsensitiveContains("itemtype=\"http://schema.org/Recipe\"") ||
              html.localizedCaseInsensitiveContains("itemtype=\"https://schema.org/Recipe\"") else {
            return nil
        }
        let title = firstMatch(in: html, pattern: #"itemprop="name"[^>]*>([^<]+)"#) ?? "Imported Recipe"
        let summary = firstMatch(in: html, pattern: #"itemprop="description"[^>]*>([^<]+)"#)
        var ingredients: [(String, Double, String, Bool)] = []
        let ingredientPattern = #"itemprop="recipeIngredient"[^>]*>([^<]+)"#
        for line in allMatches(in: html, pattern: ingredientPattern) {
            let parsed = IngredientLineParser.parse(line)
            ingredients.append((parsed.name, parsed.quantity, parsed.unit, parsed.isOptional))
        }
        var steps: [String] = allMatches(in: html, pattern: #"itemprop="recipeInstructions"[^>]*>([^<]+)"#)
        if steps.isEmpty {
            steps = allMatches(in: html, pattern: #"itemprop="text"[^>]*>([^<]+)"#)
        }
        return ImportedRecipeDraft(
            name: title,
            summary: summary,
            ingredients: ingredients,
            steps: steps
        )
    }

    private static func firstMatch(in html: String, pattern: String) -> String? {
        allMatches(in: html, pattern: pattern).first
    }

    private static func allMatches(in html: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

enum IngredientLineParser {
    struct Parsed {
        var name: String
        var quantity: Double
        var unit: String
        var isOptional: Bool
    }

    static func parse(_ line: String) -> Parsed {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let isOptional = text.localizedCaseInsensitiveContains("optional")
        text = text.replacingOccurrences(of: "(optional)", with: "", options: .caseInsensitive)

        let pattern = #"^([\d./]+)\s*([a-zA-Z]+)?\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let qtyRange = Range(match.range(at: 1), in: text),
           let nameRange = Range(match.range(at: 3), in: text) {
            let qtyString = String(text[qtyRange])
            let unitRange = Range(match.range(at: 2), in: text)
            let unit = unitRange.map { String(text[$0]).lowercased() } ?? "each"
            let name = String(text[nameRange])
            return Parsed(name: name, quantity: parseQuantity(qtyString), unit: unit, isOptional: isOptional)
        }
        return Parsed(name: text, quantity: 1, unit: "each", isOptional: isOptional)
    }

    private static func parseQuantity(_ raw: String) -> Double {
        if raw.contains("/") {
            let parts = raw.split(separator: "/")
            if parts.count == 2,
               let num = Double(parts[0]),
               let den = Double(parts[1]), den != 0 {
                return num / den
            }
        }
        return Double(raw) ?? 1
    }
}

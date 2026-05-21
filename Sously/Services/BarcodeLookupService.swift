import Foundation

struct BarcodeProductInfo: Equatable {
    var name: String
    var brand: String?
    var quantity: String?
    var categories: [String]
}

enum BarcodeLookupError: LocalizedError {
    case invalidBarcode
    case notFound
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidBarcode: "Invalid barcode."
        case .notFound: "Product not found in Open Food Facts."
        case .networkError(let error): error.localizedDescription
        }
    }
}

/// Looks up product metadata from Open Food Facts (free, no API key).
final class BarcodeLookupService: @unchecked Sendable {
    func lookup(barcode: String) async throws -> BarcodeProductInfo {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8, trimmed.allSatisfy(\.isNumber) else {
            throw BarcodeLookupError.invalidBarcode
        }

        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed).json")!
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw BarcodeLookupError.notFound
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let status = json?["status"] as? Int, status == 1,
                  let product = json?["product"] as? [String: Any] else {
                throw BarcodeLookupError.notFound
            }
            let name = (product["product_name"] as? String)
                ?? (product["generic_name"] as? String)
                ?? "Unknown product"
            let brand = product["brands"] as? String
            let quantity = product["quantity"] as? String
            let categories = (product["categories_tags"] as? [String])?
                .map { $0.replacingOccurrences(of: "en:", with: "").replacingOccurrences(of: "-", with: " ") }
                .prefix(3)
                .map { $0.capitalized } ?? []
            return BarcodeProductInfo(
                name: name,
                brand: brand,
                quantity: quantity,
                categories: Array(categories)
            )
        } catch let error as BarcodeLookupError {
            throw error
        } catch {
            throw BarcodeLookupError.networkError(error)
        }
    }
}

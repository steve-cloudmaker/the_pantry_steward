import Foundation

struct BarcodeProductInfo: Equatable {
    var name: String
    var brand: String?
    var quantity: String?
    var categories: [String]
}

enum BarcodeLookupError: LocalizedError {
    case invalidBarcode
    case notFound(attemptedSources: [String])
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            "Invalid barcode."
        case .notFound(let sources):
            if sources.isEmpty {
                "Product not found."
            } else {
                "Product not found. Tried \(sources.joined(separator: ", "))."
            }
        case .networkError(let error):
            error.localizedDescription
        }
    }
}

// MARK: - HTTP

enum BarcodeLookupHTTP {
    static let userAgent = "Sously/1.0 (iOS; pantry app; https://github.com/steve-cloudmaker/the_pantry_steward)"

    static func getJSON(url: URL, session: URLSession) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BarcodeLookupError.networkError(URLError(.badServerResponse))
        }
        guard http.statusCode == 200 else {
            return [:]
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }
}

// MARK: - Barcode variants

enum BarcodeNormalizer {
    /// Candidate codes to try (EAN-13 with leading zero vs UPC-A, etc.).
    static func lookupCandidates(for barcode: String) -> [String] {
        var ordered: [String] = [barcode]
        if barcode.count == 13, barcode.hasPrefix("0") {
            ordered.append(String(barcode.dropFirst()))
        }
        if barcode.count == 12 {
            ordered.insert("0" + barcode, at: 0)
        }
        var seen = Set<String>()
        return ordered.filter { seen.insert($0).inserted }
    }

    static func isISBN(_ barcode: String) -> Bool {
        if barcode.count == 13, barcode.hasPrefix("978") || barcode.hasPrefix("979") {
            return barcode.allSatisfy(\.isNumber)
        }
        if barcode.count == 10 {
            let prefix = barcode.dropLast()
            let check = barcode.last!
            return prefix.allSatisfy(\.isNumber) && (check.isNumber || check == "X")
        }
        return false
    }

    static func openLibraryISBN(from barcode: String) -> String {
        if barcode.count == 13, barcode.hasPrefix("978") || barcode.hasPrefix("979") {
            return String(barcode.dropFirst(3))
        }
        return barcode
    }
}

// MARK: - Providers

protocol BarcodeLookupProviding: Sendable {
    var displayName: String { get }
    func lookup(barcode: String, session: URLSession) async throws -> BarcodeProductInfo?
}

struct OpenFoodFactsBarcodeProvider: BarcodeLookupProviding {
    let displayName = "Open Food Facts"

    func lookup(barcode: String, session: URLSession) async throws -> BarcodeProductInfo? {
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode)")!
        components.queryItems = [
            URLQueryItem(name: "product_type", value: "all"),
            URLQueryItem(name: "fields", value: "product_name,generic_name,brands,quantity,categories_tags"),
        ]
        guard let url = components.url else { return nil }

        let json = try await BarcodeLookupHTTP.getJSON(url: url, session: session)
        guard let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any] else {
            return nil
        }

        let name = nonEmpty(product["product_name"] as? String)
            ?? nonEmpty(product["generic_name"] as? String)
        guard let name else { return nil }

        return BarcodeProductInfo(
            name: name,
            brand: nonEmpty(product["brands"] as? String),
            quantity: nonEmpty(product["quantity"] as? String),
            categories: parseOpenFactsCategories(product["categories_tags"] as? [String])
        )
    }

    private func parseOpenFactsCategories(_ tags: [String]?) -> [String] {
        (tags ?? [])
            .map { $0.replacingOccurrences(of: "en:", with: "").replacingOccurrences(of: "-", with: " ") }
            .prefix(3)
            .map { $0.capitalized }
            .filter { !$0.isEmpty }
            .map { String($0) }
    }
}

struct UPCitemdbBarcodeProvider: BarcodeLookupProviding {
    let displayName = "UPCitemdb"

    func lookup(barcode: String, session: URLSession) async throws -> BarcodeProductInfo? {
        var components = URLComponents(string: "https://api.upcitemdb.com/prod/trial/lookup")!
        components.queryItems = [URLQueryItem(name: "upc", value: barcode)]
        guard let url = components.url else { return nil }

        let json = try await BarcodeLookupHTTP.getJSON(url: url, session: session)
        guard (json["code"] as? String) == "OK",
              let items = json["items"] as? [[String: Any]],
              let item = items.first else {
            return nil
        }

        guard let title = nonEmpty(item["title"] as? String) else { return nil }

        return BarcodeProductInfo(
            name: title,
            brand: nonEmpty(item["brand"] as? String),
            quantity: nonEmpty(item["description"] as? String),
            categories: []
        )
    }
}

struct OpenLibraryBarcodeProvider: BarcodeLookupProviding {
    let displayName = "Open Library"

    func lookup(barcode: String, session: URLSession) async throws -> BarcodeProductInfo? {
        guard BarcodeNormalizer.isISBN(barcode) else { return nil }

        let isbn = BarcodeNormalizer.openLibraryISBN(from: barcode)
        var components = URLComponents(string: "https://openlibrary.org/api/books")!
        components.queryItems = [
            URLQueryItem(name: "bibkeys", value: "ISBN:\(isbn)"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "jscmd", value: "data"),
        ]
        guard let url = components.url else { return nil }

        let json = try await BarcodeLookupHTTP.getJSON(url: url, session: session)
        let key = "ISBN:\(isbn)"
        guard let book = json[key] as? [String: Any],
              let title = nonEmpty(book["title"] as? String) else {
            return nil
        }

        let authors = (book["authors"] as? [[String: Any]])?
            .compactMap { $0["name"] as? String }
            .joined(separator: ", ")
        let publishers = (book["publishers"] as? [[String: Any]])?
            .compactMap { $0["name"] as? String }
            .first

        var categories: [String] = []
        if let subjects = book["subjects"] as? [[String: Any]] {
            categories = subjects.compactMap { $0["name"] as? String }.prefix(3).map { String($0) }
        }

        return BarcodeProductInfo(
            name: title,
            brand: nonEmpty(authors) ?? nonEmpty(publishers),
            quantity: nonEmpty(book["publish_date"] as? String).map { "Published \($0)" },
            categories: categories
        )
    }
}

// MARK: - Service

/// Looks up product metadata using free APIs (no API key required).
final class BarcodeLookupService: @unchecked Sendable {
    private let providers: [BarcodeLookupProviding]
    private let session: URLSession

    init(providers: [BarcodeLookupProviding]? = nil, session: URLSession = .shared) {
        self.providers = providers ?? Self.defaultProviders
        self.session = session
    }

    static let defaultProviders: [BarcodeLookupProviding] = [
        OpenFoodFactsBarcodeProvider(),
        UPCitemdbBarcodeProvider(),
        OpenLibraryBarcodeProvider(),
    ]

    func lookup(barcode: String) async throws -> BarcodeProductInfo {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8, trimmed.allSatisfy(\.isNumber) || BarcodeNormalizer.isISBN(trimmed) else {
            throw BarcodeLookupError.invalidBarcode
        }

        let candidates = BarcodeNormalizer.lookupCandidates(for: trimmed)
        var attemptedSources: [String] = []
        var lastNetworkError: Error?

        for provider in providers {
            attemptedSources.append(provider.displayName)
            for code in candidates {
                do {
                    if let info = try await provider.lookup(barcode: code, session: session) {
                        return info
                    }
                } catch let error as BarcodeLookupError {
                    throw error
                } catch {
                    lastNetworkError = error
                }
            }
        }

        if let lastNetworkError {
            throw BarcodeLookupError.networkError(lastNetworkError)
        }
        throw BarcodeLookupError.notFound(attemptedSources: attemptedSources)
    }
}

// MARK: - Helpers

private func nonEmpty(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
}

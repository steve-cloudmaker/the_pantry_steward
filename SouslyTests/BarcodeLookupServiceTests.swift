import XCTest
@testable import Sously

final class BarcodeLookupServiceTests: XCTestCase {
    func testLookupCandidatesAddsEANFromUPC() {
        let candidates = BarcodeNormalizer.lookupCandidates(for: "885909950805")
        XCTAssertEqual(candidates.first, "0885909950805")
        XCTAssertTrue(candidates.contains("885909950805"))
    }

    func testLookupCandidatesStripsLeadingZeroFromEAN() {
        let candidates = BarcodeNormalizer.lookupCandidates(for: "0885909950805")
        XCTAssertTrue(candidates.contains("0885909950805"))
        XCTAssertTrue(candidates.contains("885909950805"))
    }

    func testIsISBNRecognizesBookEAN() {
        XCTAssertTrue(BarcodeNormalizer.isISBN("9780140157370"))
        XCTAssertFalse(BarcodeNormalizer.isISBN("3017620422003"))
    }

    func testOpenLibraryISBNStrips978Prefix() {
        XCTAssertEqual(BarcodeNormalizer.openLibraryISBN(from: "9780140157370"), "0140157370")
    }

    func testLookupUsesFirstSuccessfulProvider() async throws {
        let off = StubBarcodeProvider(name: "Open Food Facts", result: BarcodeProductInfo(
            name: "Nutella",
            brand: "Ferrero",
            quantity: "400 g",
            categories: ["Spreads"]
        ))
        let upc = StubBarcodeProvider(name: "UPCitemdb", result: BarcodeProductInfo(
            name: "Should not win",
            brand: nil,
            quantity: nil,
            categories: []
        ))
        let service = BarcodeLookupService(providers: [off, upc])

        let info = try await service.lookup(barcode: "3017620422003")
        XCTAssertEqual(info.name, "Nutella")
        XCTAssertEqual(off.lookupCount, 1)
        XCTAssertEqual(upc.lookupCount, 0)
    }

    func testLookupFallsBackToSecondProvider() async throws {
        let off = StubBarcodeProvider(name: "Open Food Facts", result: nil)
        let upc = StubBarcodeProvider(name: "UPCitemdb", result: BarcodeProductInfo(
            name: "iPhone 6",
            brand: "Apple",
            quantity: nil,
            categories: []
        ))
        let library = StubBarcodeProvider(name: "Open Library", result: nil)
        let service = BarcodeLookupService(providers: [off, upc, library])

        let info = try await service.lookup(barcode: "0885909950805")
        XCTAssertEqual(info.name, "iPhone 6")
        XCTAssertGreaterThanOrEqual(off.lookupCount, 1)
        XCTAssertGreaterThanOrEqual(upc.lookupCount, 1)
    }

    func testLookupNotFoundListsSources() async {
        let off = StubBarcodeProvider(name: "Open Food Facts", result: nil)
        let upc = StubBarcodeProvider(name: "UPCitemdb", result: nil)
        let service = BarcodeLookupService(providers: [off, upc])

        do {
            _ = try await service.lookup(barcode: "1234567890123")
            XCTFail("Expected notFound")
        } catch let error as BarcodeLookupError {
            if case .notFound(let sources) = error {
                XCTAssertEqual(sources, ["Open Food Facts", "UPCitemdb"])
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidBarcode() async {
        let service = BarcodeLookupService(providers: [])
        do {
            _ = try await service.lookup(barcode: "abc")
            XCTFail("Expected invalidBarcode")
        } catch let error as BarcodeLookupError {
            if case .invalidBarcode = error {
                // expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class StubBarcodeProvider: BarcodeLookupProviding, @unchecked Sendable {
    let displayName: String
    let result: BarcodeProductInfo?
    private(set) var lookupCount = 0

    init(name: String, result: BarcodeProductInfo?) {
        self.displayName = name
        self.result = result
    }

    func lookup(barcode: String, session: URLSession) async throws -> BarcodeProductInfo? {
        lookupCount += 1
        return result
    }
}

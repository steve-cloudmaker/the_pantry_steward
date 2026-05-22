import CoreData
import XCTest
@testable import Sously

@MainActor
final class SeedDataServiceTests: XCTestCase {
    override func setUp() async throws {
        SeedDataService.resetSeedFlag()
    }

    func testSeedIsIdempotent() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.viewContext

        SeedDataService.seedIfNeeded(context: context)
        SeedDataService.seedIfNeeded(context: context)

        let request = PantryItem.fetchRequest()
        let count = try context.count(for: request)
        XCTAssertEqual(count, 5)
    }

    func testSkipsSeedWhenPantryAlreadyHasItems() throws {
        SeedDataService.resetSeedFlag()
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.viewContext
        let pantry = PantryRepository(context: context)

        _ = try pantry.create(name: "Existing Item")
        SeedDataService.seedIfNeeded(context: context)

        let request = PantryItem.fetchRequest()
        let count = try context.count(for: request)
        XCTAssertEqual(count, 1)
    }
}

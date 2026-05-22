import XCTest

final class SouslyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTabBarNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-com.sously.ui-testing"]
        app.launch()

        let pantryTab = app.tabBars.buttons["Pantry"]
        let pantryNav = app.navigationBars["Pantry"]
        XCTAssertTrue(pantryTab.waitForExistence(timeout: 25) || pantryNav.waitForExistence(timeout: 25))
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.navigationBars["Shopping"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Cook"].tap()
        XCTAssertTrue(app.navigationBars["Cook"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Recipes"].tap()
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.navigationBars["Meal Plans"].waitForExistence(timeout: 3))
    }
}

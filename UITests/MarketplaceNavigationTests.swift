import XCTest

@MainActor
final class MarketplaceNavigationTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() async throws {
        attachScreenshot("Final navigation state")
        app.terminate()
    }

    func testSkillDetailReturnsToListWithOneBackAction() throws {
        let allSkills = app.buttons["catalog.all"]
        XCTAssertTrue(allSkills.waitForExistence(timeout: 30))
        allSkills.tap()

        let results = app.scrollViews["catalog.results"]
        XCTAssertTrue(results.waitForExistence(timeout: 60))
        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "skill.card.")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        let cardIdentifier = card.identifier
        attachScreenshot("Skill list before entry")

        for attempt in 1...2 {
            app.buttons[cardIdentifier].tap()
            XCTAssertTrue(app.otherElements["skill.detail"].waitForExistence(timeout: 15))
            attachScreenshot("Detail entry \(attempt)")

            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(results.waitForExistence(timeout: 15), "One back action must return to the skill list")
            XCTAssertTrue(app.buttons[cardIdentifier].isHittable)
            XCTAssertFalse(app.otherElements["skill.detail"].exists)
            attachScreenshot("List after one back action \(attempt)")
        }

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(allSkills.waitForExistence(timeout: 15), "The next back action must return to the catalog")
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

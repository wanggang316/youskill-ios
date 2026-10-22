import XCTest

@MainActor
final class ReleaseAcceptanceTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-fixtures", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["catalog.all"].waitForExistence(timeout: 30))
    }

    override func tearDown() async throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Failed acceptance hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    func testRotationPreservesTheOpenReaderAndBackStack() {
        openResults()
        firstCard.tap()
        let reader = app.scrollViews["skill.detail"]
        XCTAssertTrue(reader.waitForExistence(timeout: 60))
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in
            self.app.frame.width > self.app.frame.height
        }
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 15)
        XCTAssertTrue(reader.exists)
        XCUIDevice.shared.orientation = .portrait
        app.buttons["BackButton"].tap()
        XCTAssertTrue(app.scrollViews["catalog.results"].waitForExistence(timeout: 15))
        app.buttons["BackButton"].tap()
        XCTAssertTrue(app.buttons["catalog.all"].waitForExistence(timeout: 15))
    }

    func testSearchSortAndFavoritePersistence() {
        openResults()
        XCTAssertEqual(firstCard.identifier, "skill.card.1")
        app.buttons["catalog.sort"].tap()
        app.buttons["Most Starred"].tap()
        let sorted = NSPredicate { _, _ in self.firstCard.identifier == "skill.card.2" }
        expectation(for: sorted, evaluatedWith: app)
        waitForExpectations(timeout: 15)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("find-skills\n")
        let matchingName = app.staticTexts.matching(NSPredicate(format: "label == %@", "find-skills")).firstMatch
        XCTAssertTrue(matchingName.waitForExistence(timeout: 30))
        let filtered = NSPredicate { _, _ in
            self.app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "skill.card.")).count == 1
                && self.firstCard.identifier == "skill.card.1"
        }
        expectation(for: filtered, evaluatedWith: app)
        waitForExpectations(timeout: 15)

        let card = firstCard
        let cardID = card.identifier
        let skillID = String(cardID.dropFirst("skill.card.".count))
        let favorite = app.buttons["skill.favorite.\(skillID)"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 10))
        favorite.tap()
        XCTAssertEqual(favorite.label, "Remove favorite")
        XCTAssertTrue(app.scrollViews["catalog.results"].exists, "Saving a favorite must not open the reader")

        app.terminate()
        app.launchArguments.removeAll { $0 == "--ui-testing" }
        app.launch()
        let favorites = app.buttons["catalog.favorites"]
        XCTAssertTrue(favorites.waitForExistence(timeout: 30))
        favorites.tap()
        XCTAssertTrue(app.buttons[cardID].waitForExistence(timeout: 15))
        app.buttons["skill.favorite.\(skillID)"].tap()
        XCTAssertTrue(app.staticTexts["No favorites yet"].waitForExistence(timeout: 15))
    }

    func testFilesAndTranslationSettingsCompleteTheReadingFlow() {
        openResults()
        firstCard.tap()
        XCTAssertTrue(app.scrollViews["skill.detail"].waitForExistence(timeout: 15))
        app.buttons["detail.files"].tap()
        let sourceFile = app.buttons["detail.file.example.swift"]
        XCTAssertTrue(sourceFile.waitForExistence(timeout: 10))
        sourceFile.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "example.swift")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["detail.translate"].isEnabled)

        app.buttons["detail.files"].tap()
        app.buttons["detail.file.archive.zip"].tap()
        XCTAssertTrue(app.staticTexts["Preview not available"].waitForExistence(timeout: 10))
        app.buttons["detail.files"].tap()
        app.buttons["detail.file.SKILL.md"].tap()
        XCTAssertTrue(app.staticTexts["Skill guide"].waitForExistence(timeout: 10))
        app.buttons["detail.translate"].tap()
        let setup = app.alerts.firstMatch
        XCTAssertTrue(setup.waitForExistence(timeout: 10))
        setup.buttons["Open Settings"].tap()
        let modelSettings = app.buttons["settings.model"]
        XCTAssertTrue(modelSettings.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: modelSettings)
        waitForExpectations(timeout: 10)
        modelSettings.tap()
        let checkConnection = app.buttons["settings.check"]
        XCTAssertTrue(checkConnection.waitForExistence(timeout: 10))
        checkConnection.tap()
        XCTAssertTrue(app.staticTexts["settings.check-failure"].waitForExistence(timeout: 10))
        replaceText(in: app.textFields["settings.base-url"], with: "https://example.invalid/v1")
        app.secureTextFields["settings.api-key"].tap()
        app.secureTextFields["settings.api-key"].typeText("ui-test-key")
        replaceText(in: app.textFields["settings.model-name"], with: "ui-test-model")
        app.buttons["settings.check"].tap()
        XCTAssertTrue(app.staticTexts["Connection verified"].waitForExistence(timeout: 10))
        app.buttons["settings.save"].tap()
        app.buttons["settings.done"].tap()
        app.buttons["detail.translate"].tap()
        XCTAssertTrue(app.staticTexts["Translated guide"].waitForExistence(timeout: 15))
        app.buttons["detail.translate"].tap()
        XCTAssertTrue(app.staticTexts["Skill guide"].waitForExistence(timeout: 15))
    }

    func testCatalogScopesAndFailedLoadRetry() {
        let category = app.buttons["catalog.category.1"]
        XCTAssertTrue(category.waitForExistence(timeout: 15))
        category.tap()
        XCTAssertTrue(app.navigationBars["Development"].waitForExistence(timeout: 15))
        XCTAssertTrue(firstCard.waitForExistence(timeout: 15))
        app.buttons["BackButton"].tap()
        app.buttons["catalog.repositories"].tap()
        let repository = app.buttons["catalog.repository.1"]
        XCTAssertTrue(repository.waitForExistence(timeout: 15))
        repository.tap()
        XCTAssertTrue(app.navigationBars["example/skills"].waitForExistence(timeout: 15))
        XCTAssertTrue(firstCard.waitForExistence(timeout: 15))

        app.terminate()
        app.launchArguments.append("--ui-error-once")
        app.launch()
        XCTAssertTrue(app.buttons["catalog.all"].waitForExistence(timeout: 30))
        app.buttons["catalog.all"].tap()
        let retry = app.buttons["Retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15))
        retry.tap()
        XCTAssertTrue(firstCard.waitForExistence(timeout: 15))
    }

    private func replaceText(in field: XCUIElement, with value: String) {
        field.tap()
        let current = field.value as? String ?? ""
        if !current.isEmpty && current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(value)
    }

    private var firstCard: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "skill.card.")).firstMatch
    }

    private func openResults() {
        app.buttons["catalog.all"].tap()
        XCTAssertTrue(app.scrollViews["catalog.results"].waitForExistence(timeout: 60))
        XCTAssertTrue(firstCard.waitForExistence(timeout: 15))
    }
}

import XCTest

@MainActor
final class FavoriteSyncAcceptanceTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-fixtures", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    override func tearDown() async throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Failed favorite sync hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        app.terminate()
    }

    func testSignedOutSettingsOfferAppleAndGitHubEqually() {
        launch()
        openSettings()

        let apple = app.buttons["account.sign-in.apple"]
        let github = app.buttons["account.sign-in.github"]
        XCTAssertTrue(apple.waitForExistence(timeout: 15))
        XCTAssertTrue(github.exists)
        XCTAssertEqual(apple.label, "Sign in with Apple")
        XCTAssertEqual(github.label, "Sign in with GitHub")
        XCTAssertEqual(apple.frame.width, github.frame.width, accuracy: 0.5)
        XCTAssertEqual(apple.frame.height, github.frame.height, accuracy: 0.5)
        XCTAssertFalse(app.buttons["account.delete"].exists)
        attachScreenshot("settings-signed-out")
    }

    func testUnavailableFavoriteShowsSnapshotAndCanBeRemoved() {
        launch("--ui-unavailable-favorite")
        let favorites = app.buttons["catalog.favorites"]
        XCTAssertTrue(favorites.waitForExistence(timeout: 30))
        favorites.tap()

        XCTAssertTrue(app.staticTexts["retired-skill"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["example/archive"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["skill.unavailable.99"].waitForExistence(timeout: 15))
        attachScreenshot("favorite-unavailable")

        app.staticTexts["retired-skill"].tap()
        XCTAssertFalse(app.scrollViews["skill.detail"].waitForExistence(timeout: 2),
                       "An unavailable favorite must not open the reader")

        let remove = app.buttons["skill.favorite.99"]
        XCTAssertEqual(remove.label, "Remove favorite")
        remove.tap()
        XCTAssertTrue(app.staticTexts["No favorites yet"].waitForExistence(timeout: 15))
    }

    func testSignedInSettingsShowIdentityAndDeleteAfterConfirmation() {
        launch("--ui-signed-in")
        openSettings()

        let identity = app.descendants(matching: .any)["account.identity"]
        XCTAssertTrue(identity.waitForExistence(timeout: 15))
        XCTAssertEqual(identity.label, "Signed in with GitHub, Ada Lovelace")
        XCTAssertFalse(app.buttons["account.sign-in.apple"].exists)
        attachScreenshot("settings-signed-in")

        app.buttons["account.delete"].tap()
        XCTAssertTrue(app.staticTexts["Delete your account?"].waitForExistence(timeout: 10))
        attachScreenshot("delete-confirmation")
        let confirm = app.buttons.matching(NSPredicate(
            format: "label == %@ AND identifier != %@", "Delete Account", "account.delete"
        )).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        confirm.tap()

        XCTAssertTrue(app.buttons["account.sign-in.apple"].waitForExistence(timeout: 15))
        XCTAssertFalse(identity.exists)
    }

    private func launch(_ arguments: String...) {
        app.launchArguments += arguments
        app.launch()
        XCTAssertTrue(app.buttons["catalog.all"].waitForExistence(timeout: 30))
    }

    private func openSettings() {
        let settings = app.buttons["catalog.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        settings.tap()
    }

    private func attachScreenshot(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "issue-5-\(name)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

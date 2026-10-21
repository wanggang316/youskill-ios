import XCTest

@MainActor
final class StoreScreenshotTests: XCTestCase {
    func testStoreScreenshots() throws {
        continueAfterFailure = false
        let configuration = try ScreenshotConfiguration.load()
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(\(configuration.language))",
                               "-AppleLocale", configuration.locale]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["catalog.all"].waitForExistence(timeout: 30))
        let category = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog.category.")).firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 60))
        try capture("01-categories", app: app, configuration: configuration)

        app.buttons["catalog.repositories"].tap()
        let repository = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog.repository.")).firstMatch
        XCTAssertTrue(repository.waitForExistence(timeout: 60))
        try capture("02-repositories", app: app, configuration: configuration)

        repository.tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "skill.card.")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 60))
        try capture("03-skills", app: app, configuration: configuration)
        card.tap()
        XCTAssertTrue(app.scrollViews["skill.detail"].waitForExistence(timeout: 60))
        let loaded = NSPredicate(format: "exists == true AND enabled == true")
        expectation(for: loaded, evaluatedWith: app.buttons["detail.translate"])
        waitForExpectations(timeout: 60)
        try capture("04-reader", app: app, configuration: configuration)

        app.buttons["BackButton"].tap()
        XCTAssertTrue(app.scrollViews["catalog.results"].waitForExistence(timeout: 15))
        app.buttons["BackButton"].tap()
        app.buttons["catalog.settings"].tap()
        XCTAssertTrue(app.buttons["settings.model"].waitForExistence(timeout: 15))
        try capture("05-settings", app: app, configuration: configuration)
    }

    private func capture(_ name: String, app: XCUIApplication, configuration: ScreenshotConfiguration) throws {
        let screenshot = app.screenshot()
        let destination = URL(fileURLWithPath: configuration.outputDirectory)
            .appendingPathComponent(name).appendingPathExtension("png")
        try screenshot.pngRepresentation.write(to: destination, options: .atomic)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private struct ScreenshotConfiguration: Decodable {
    let language: String
    let locale: String
    let outputDirectory: String

    static func load() throws -> ScreenshotConfiguration {
        let hostHome = try XCTUnwrap(ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"],
                                    "Store screenshots require an iOS simulator.")
        // A host-side configuration preserves the device posture across localized runs.
        let url = URL(fileURLWithPath: hostHome)
            .appendingPathComponent("Library/Caches/com.gumpw.youskill.screenshots/config.json")
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}

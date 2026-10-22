import XCTest
import CoreGraphics
import ImageIO

@MainActor
final class StoreScreenshotTests: XCTestCase {
    func testStoreScreenshots() throws {
        continueAfterFailure = false
        let configuration = try ScreenshotConfiguration.load()
        XCUIDevice.shared.orientation = configuration.posture == "open" ? .landscapeLeft : .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(\(configuration.language))",
                               "-AppleLocale", configuration.locale]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["catalog.all"].waitForExistence(timeout: 30))
        let category = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog.category.")).firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 60))
        if configuration.posture == "open" {
            let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "skill.card.")).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 60))
        }
        try capture("01-categories", configuration: configuration)

        app.buttons["catalog.repositories"].tap()
        let repository = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog.repository.")).firstMatch
        XCTAssertTrue(repository.waitForExistence(timeout: 60))
        try capture("02-repositories", configuration: configuration)

        let featuredRepository = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "catalog.repository.", "mattpocock/skills"
        )).firstMatch
        if !featuredRepository.isHittable { app.swipeUp() }
        XCTAssertTrue(featuredRepository.waitForExistence(timeout: 15))
        featuredRepository.tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "skill.card.")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 60))
        try capture("03-skills", configuration: configuration)
        card.tap()
        XCTAssertTrue(app.scrollViews["skill.detail"].waitForExistence(timeout: 60))
        let loaded = NSPredicate(format: "exists == true AND enabled == true")
        expectation(for: loaded, evaluatedWith: app.buttons["detail.translate"])
        waitForExpectations(timeout: 60)
        try capture("04-reader", configuration: configuration)

        app.buttons["BackButton"].tap()
        XCTAssertTrue(app.scrollViews["catalog.results"].waitForExistence(timeout: 15))
        if !app.buttons["catalog.settings"].isHittable {
            app.buttons["BackButton"].tap()
        }
        app.buttons["catalog.settings"].tap()
        XCTAssertTrue(app.buttons["settings.model"].waitForExistence(timeout: 15))
        try capture("05-settings", configuration: configuration)
    }

    private func capture(_ name: String, configuration: ScreenshotConfiguration) throws {
        let directory = URL(fileURLWithPath: configuration.outputDirectory)
        let response = directory.appendingPathComponent("\(name).capture.json")
        let request = try JSONSerialization.data(withJSONObject: ["name": name])
        try request.write(to: directory.appendingPathComponent("capture-request.json"), options: .atomic)
        let completed = NSPredicate { _, _ in FileManager.default.fileExists(atPath: response.path) }
        expectation(for: completed, evaluatedWith: nil)
        waitForExpectations(timeout: 90)
        let result = try JSONDecoder().decode(CaptureResult.self, from: Data(contentsOf: response))
        XCTAssertTrue(result.success, result.error ?? "Native screenshot capture failed")
        let destination = directory.appendingPathComponent(name).appendingPathExtension("png")
        let capturedData = try Data(contentsOf: destination)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(capturedData as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        // App Store screenshots require opaque pixels. Preserve the native pixel dimensions.
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.draw(image, in: bounds)
        let opaqueImage = try XCTUnwrap(context.makeImage())
        let encoded = NSMutableData()
        let encoder = try XCTUnwrap(CGImageDestinationCreateWithData(encoded, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(encoder, opaqueImage, nil)
        XCTAssertTrue(CGImageDestinationFinalize(encoder))
        let data = encoded as Data
        try data.write(to: destination, options: .atomic)
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: data, userInfo: nil)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private struct CaptureResult: Decodable {
    let success: Bool
    let error: String?
}

private struct ScreenshotConfiguration: Decodable {
    let language: String
    let locale: String
    let outputDirectory: String
    let posture: String

    static func load() throws -> ScreenshotConfiguration {
        let hostHome = try XCTUnwrap(ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"],
                                    "Store screenshots require an iOS simulator.")
        // A host-side configuration preserves the device posture across localized runs.
        let url = URL(fileURLWithPath: hostHome)
            .appendingPathComponent("Library/Caches/com.gumpw.youskill.screenshots/config.json")
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}

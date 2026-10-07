import XCTest

/// Launches every screen in demo mode (sample data, no Screen Time) and attaches a screenshot.
/// CI exports these so the UI can be reviewed without a device.
final class ScreenshotTour: XCTestCase {
    private let screens = [
        "onboarding0", "onboarding1", "onboarding2", "onboarding3", "onboarding4", "onboarding5",
        "home", "home-locked",
        "intervention-breathing", "intervention-intention", "intervention-replacement",
        "intervention-duration", "intervention-done", "intervention-gaveup",
        "locks", "lock-editor", "manual-lock", "unlock", "key",
        "stats", "settings", "replacements", "tips",
    ]

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testTour() {
        for (index, screen) in screens.enumerated() {
            let app = XCUIApplication()
            app.launchArguments = ["-regaDemo", screen]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), screen)
            sleep(2)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = String(format: "%02d-%@", index, screen)
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }

    func testInterventionGiveUpIsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-regaDemo", "intervention-intention"]
        app.launch()
        let giveUp = app.buttons["בעצם, ויתרתי"]
        XCTAssertTrue(giveUp.waitForExistence(timeout: 10))
        giveUp.tap()
        XCTAssertTrue(app.staticTexts["יפה."].waitForExistence(timeout: 5))
    }
}

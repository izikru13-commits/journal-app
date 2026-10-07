import XCTest

/// Runs the real app in the simulator against a photo library seeded by CI (see TestMedia/),
/// walks through onboarding → swiping → summary → deletion, and saves screenshots.
final class SwipeCleanUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Taps the first matching button on any system alert (Photos permission, delete/modify confirmations).
    @discardableResult
    private func acceptSystemAlert(timeout: TimeInterval = 5) -> Bool {
        let labels = ["Allow Full Access", "Allow Access to All Photos", "Delete", "Modify", "Allow", "OK",
                      "אפשר גישה מלאה", "מחק", "שנה", "אפשר", "אישור"]
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for source in [app!, springboard] {
            let alert = source.alerts.firstMatch
            if alert.waitForExistence(timeout: timeout) {
                for label in labels where alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
                // Fall back to the last (usually confirming) button.
                let buttons = alert.buttons
                if buttons.count > 0 {
                    buttons.element(boundBy: buttons.count - 1).tap()
                    return true
                }
            }
        }
        return false
    }

    private var topCard: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "card.top").firstMatch
    }

    private func reviewedCount() -> Int {
        Int(app.staticTexts["stat.reviewed"].label) ?? -1
    }

    func testFullCleaningFlow() throws {
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for label in ["Allow Full Access", "Allow Access to All Photos", "Allow", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        app.launch()

        // Onboarding: 3 pages, last button requests gallery access.
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        snap("01-onboarding-1")
        next.tap()
        snap("02-onboarding-privacy")
        next.tap()
        snap("03-onboarding-safety")
        next.tap()
        acceptSystemAlert(timeout: 3)
        app.tap() // lets the interruption monitor fire if an alert is still up

        // Home
        let start = app.buttons["home.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "home screen should appear after granting access")
        let total = app.staticTexts["home.total"]
        let counted = NSPredicate(format: "label != '0'")
        expectation(for: counted, evaluatedWith: total)
        waitForExpectations(timeout: 20)
        snap("04-home")

        // Swipe session
        start.tap()
        let card = topCard
        XCTAssertTrue(card.waitForExistence(timeout: 20), "a photo card should be shown")
        snap("05-session-start")

        card.swipeLeft()                               // delete
        XCTAssertTrue(topCard.waitForExistence(timeout: 5))
        topCard.swipeRight()     // keep
        XCTAssertTrue(topCard.waitForExistence(timeout: 5))
        topCard.swipeUp()        // favorite
        sleep(1)
        XCTAssertEqual(reviewedCount(), 3, "three swipes should review three items")
        XCTAssertEqual(app.staticTexts["stat.deletes"].label, "1")

        // Buttons do the same
        app.buttons["action.delete"].tap()
        sleep(1)
        app.buttons["action.keep"].tap()
        sleep(1)
        XCTAssertEqual(reviewedCount(), 5)
        XCTAssertEqual(app.staticTexts["stat.deletes"].label, "2")
        snap("06-session-after-swipes")

        // Undo the last "keep"
        app.buttons["action.undo"].tap()
        sleep(1)
        XCTAssertEqual(reviewedCount(), 4)
        app.buttons["action.delete"].tap()
        sleep(1)
        XCTAssertEqual(app.staticTexts["stat.deletes"].label, "3")

        // Finish → summary
        app.buttons["session.finish"].tap()
        let commit = app.buttons["summary.commit"]
        XCTAssertTrue(commit.waitForExistence(timeout: 10))
        let thumbs = app.buttons.matching(identifier: "summary.thumb")
        XCTAssertEqual(thumbs.count, 3)
        snap("07-summary")

        // Rescue one item from deletion
        thumbs.element(boundBy: 0).tap()
        sleep(1)
        XCTAssertEqual(app.buttons.matching(identifier: "summary.thumb").count, 2)
        snap("08-summary-after-rescue")

        // Confirm: favorites (modify prompt) + deletion (delete prompt)
        commit.tap()
        acceptSystemAlert(timeout: 8)
        acceptSystemAlert(timeout: 8)

        let done = app.buttons["celebration.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 20), "celebration screen should appear after deleting")
        sleep(1)
        snap("09-celebration")
        done.tap()

        // Back home: progress continues, 2 deletions recorded.
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        sleep(2)
        snap("10-home-after")
    }

    func testProgressContinuesAfterRelaunch() throws {
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for label in ["Allow Full Access", "Allow Access to All Photos", "Allow", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        app.launch()
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        next.tap(); next.tap(); next.tap()
        acceptSystemAlert(timeout: 3)
        app.tap()

        let start = app.buttons["home.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()
        XCTAssertTrue(topCard.waitForExistence(timeout: 20))
        let firstSource = topCard.label
        _ = firstSource
        app.buttons["action.keep"].tap()
        sleep(1)
        app.buttons["action.keep"].tap()
        sleep(1)
        app.buttons["session.finish"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        snap("11-home-continue-button")
        XCTAssertTrue(start.label.contains("המשך"), "after reviewing, the main button should offer to continue")

        // Relaunch WITHOUT the fresh-start flag: progress must still be there.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["home.start"].label.contains("המשך"), "progress should persist across launches")
        snap("12-home-after-relaunch")
    }
}

import XCTest

final class ShadcnGalleryTests: XCTestCase {
    private func open(_ slug: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--shadcn", slug]
        app.launch()
        return app
    }

    private func record(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testDialogOpensAndReturnsToTheTrigger() {
        let app = open("dialog")
        let trigger = app.buttons["Open Dialog"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 8))
        trigger.tap()
        XCTAssertTrue(app.staticTexts["Edit profile"].waitForExistence(timeout: 5))
        record("Dialog open", app)
        app.buttons["Save changes"].tap()
        XCTAssertTrue(trigger.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Edit profile"].exists)
    }

    func testQuestionnaireValidatesAndPreservesPreviousAnswer() {
        let app = open("questionnaire")
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        next.tap()
        XCTAssertTrue(app.staticTexts["Select an answer to continue."].exists)
        app.buttons["Only the target component"].tap()
        next.tap()
        XCTAssertTrue(app.staticTexts["Question 2 of 3"].exists)
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Only the target component"].isSelected)
        record("Questionnaire selected", app)
    }

    func testSonnerShowsNotificationAndUndoDismissesIt() {
        let app = open("sonner")
        let trigger = app.buttons["Show Toast"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 8))
        trigger.tap()
        let notice = app.staticTexts["Event has been created"]
        XCTAssertTrue(notice.waitForExistence(timeout: 3))
        app.buttons["Undo"].tap()
        XCTAssertFalse(notice.exists)
    }

    func testCarouselSupportsNextAndPrevious() {
        let app = open("carousel")
        let next = app.buttons["Next slide"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        next.tap()
        XCTAssertTrue(app.staticTexts["2"].exists)
        app.buttons["Previous slide"].tap()
        XCTAssertTrue(app.staticTexts["1"].exists)
        XCTAssertFalse(app.buttons["Previous slide"].isEnabled)
    }

    func testRadioOptionsKeepSeparateTouchableRows() {
        let app = open("radio-group")
        let first = app.buttons["Default"], middle = app.buttons["Comfortable"]
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        XCTAssertGreaterThanOrEqual(first.frame.height, 44)
        XCTAssertLessThanOrEqual(first.frame.maxY, middle.frame.minY + 0.5)
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.05)).tap()
        XCTAssertTrue(first.isSelected)
        XCTAssertFalse(middle.isSelected)
    }

    func testDataTableFilterOnlySearchesTheEmailColumn() {
        let app = open("data-table")
        let filter = app.textFields.firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 8))
        filter.tap()
        filter.typeText("Success")
        XCTAssertTrue(app.staticTexts["No results."].waitForExistence(timeout: 3))
    }
}

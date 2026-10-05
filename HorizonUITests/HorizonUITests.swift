import XCTest

/// Smoke tests on the simulator. Every test starts from a clean store, in Paris on
/// 29 September 2026 at 16:17, the scene of the mockups: sunrise 7:47, sunset 19:33.
final class HorizonUITests: XCTestCase {
    private let scene = [
        "-horizonReset", "YES",
        "-horizonLocation", "48.8566,2.3522",
        "-horizonTimeZone", "Europe/Paris",
        "-horizonNow", "2026-09-29T16:17:00+02:00",
        "-horizonSkipPrompts", "YES",
        "-AppleLanguages", "(en)",
        "-AppleLocale", "en_GB"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extra: [String] = ["-horizonSkipOnboarding", "YES"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = scene + extra
        app.launch()
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func labelled(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    @MainActor
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testOnboardingEndsOnTheMainScreenWithBothAlarmsOn() {
        let app = launch([])
        let action = app.buttons["onboarding.action"]

        XCTAssertTrue(action.waitForExistence(timeout: 20))
        XCTAssertEqual(action.label, "Get started")
        attach("onboarding-1-welcome")
        action.tap()

        XCTAssertTrue(app.staticTexts["Where are you?"].waitForExistence(timeout: 5))
        attach("onboarding-2-location")
        action.tap()

        XCTAssertTrue(app.staticTexts["Never miss it"].waitForExistence(timeout: 5))
        attach("onboarding-3-notifications")
        action.tap()

        XCTAssertTrue(app.staticTexts["Your alarms"].waitForExistence(timeout: 5))
        XCTAssertTrue(labelled(app, containing: "7:48 tomorrow").exists)
        XCTAssertTrue(labelled(app, containing: "19:33 tonight").exists)
        attach("onboarding-4-alarms")
        app.swipeUp()
        action.tap()

        XCTAssertTrue(element(app, "pill").waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["bell.sunrise"].value as? String, "On")
        XCTAssertEqual(app.buttons["bell.sunset"].value as? String, "On")
        attach("main-after-onboarding")
    }

    @MainActor
    func testMainScreenShowsTheMockupTimes() {
        let app = launch()
        XCTAssertTrue(element(app, "time.sunrise").waitForExistence(timeout: 20))
        XCTAssertEqual(element(app, "time.sunrise").label, "7:47")
        XCTAssertEqual(element(app, "time.sunset").label, "19:33")
        XCTAssertEqual(element(app, "daylight").label, "11h 46m of daylight")
        XCTAssertTrue(element(app, "countdown").label.hasPrefix("Sunset in"))
        XCTAssertEqual(element(app, "pill").label, "Automatic alarm")
    }

    @MainActor
    func testTappingABellTogglesThatAlarm() {
        let app = launch()
        let sunrise = app.buttons["bell.sunrise"]
        XCTAssertTrue(sunrise.waitForExistence(timeout: 20))
        XCTAssertEqual(sunrise.value as? String, "On")

        sunrise.tap()
        XCTAssertTrue(element(app, "toast").waitForExistence(timeout: 2))
        XCTAssertEqual(element(app, "toast").label, "Sunrise alarm off")
        XCTAssertEqual(sunrise.value as? String, "Off")
        attach("toast-sunrise-off")

        // The confirmation leaves after two seconds; sunset still rings.
        XCTAssertTrue(element(app, "pill").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "pill").label, "Automatic alarm")

        app.buttons["bell.sunset"].tap()
        XCTAssertTrue(element(app, "pill").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "pill").label, "Tap a bell")

        sunrise.tap()
        XCTAssertTrue(element(app, "toast").waitForExistence(timeout: 2))
        XCTAssertTrue(element(app, "toast").label.hasPrefix("Sunrise alarm on"))
        XCTAssertEqual(sunrise.value as? String, "On")
    }

    @MainActor
    func testTappingTheCountdownSwitchesToTheOtherEvent() {
        let app = launch()
        let countdown = element(app, "countdown")
        XCTAssertTrue(countdown.waitForExistence(timeout: 20))
        XCTAssertTrue(countdown.label.hasPrefix("Sunset in"))

        countdown.tap()
        XCTAssertTrue(element(app, "countdown").label.hasPrefix("Sunrise in"))
        XCTAssertEqual(element(app, "time.sunrise").label, "7:48")
        XCTAssertTrue(app.staticTexts["Sunrise tomorrow"].exists)
        attach("countdown-switched")

        element(app, "countdown").tap()
        XCTAssertTrue(element(app, "countdown").label.hasPrefix("Sunset in"))
        XCTAssertEqual(element(app, "time.sunrise").label, "7:47")
    }
}

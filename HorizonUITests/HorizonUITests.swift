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

    /// The week list scrolls before it pages, so swipe until the settings page is there.
    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["bell.sunrise"].waitForExistence(timeout: 20))
        for _ in 0..<8 where !app.switches["settings.sunrise"].isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(app.switches["settings.sunrise"].isHittable)
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
        // Done arms the next occurrence, here tonight's sunset.
        XCTAssertEqual(element(app, "pill").label, "Persistent alarm")
        XCTAssertTrue(app.buttons["bell.sunset"].isSelected)
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
        // The app is in the foreground, so the next occurrence is armed as a persistent alarm.
        XCTAssertEqual(element(app, "pill").label, "Persistent alarm")
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
        XCTAssertEqual(element(app, "pill").label, "Persistent alarm")

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

    // MARK: - Alarm

    @MainActor
    func testStopOnTheAlarmScreenReturnsToTheArc() {
        let app = launch(["-horizonSkipOnboarding", "YES", "-horizonRing", "sunset"])
        let stop = app.buttons["alarm.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 20))
        XCTAssertEqual(stop.label, "Stop")
        XCTAssertTrue(app.staticTexts["Sunset"].exists)
        XCTAssertTrue(app.staticTexts["19:33"].exists)
        XCTAssertTrue(app.staticTexts["Paris"].exists)
        attach("alarm-sunset")

        stop.tap()
        XCTAssertTrue(element(app, "pill").waitForExistence(timeout: 5))
        XCTAssertFalse(stop.exists)
    }

    @MainActor
    func testSunriseAlarmScreen() {
        let app = launch(["-horizonSkipOnboarding", "YES", "-horizonRing", "sunrise"])
        XCTAssertTrue(app.buttons["alarm.stop"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Sunrise"].exists)
        XCTAssertTrue(app.staticTexts["7:48"].exists)
        attach("alarm-sunrise")
    }

    // MARK: - Pages

    @MainActor
    func testWeekPageSkipsAndRestoresOneOccurrence() {
        let app = launch()
        XCTAssertTrue(app.buttons["bell.sunrise"].waitForExistence(timeout: 20))
        app.swipeUp()

        let thursday = element(app, "week.sunrise-2026-10-01")
        XCTAssertTrue(thursday.waitForExistence(timeout: 5))
        XCTAssertTrue(labelled(app, containing: "Today").exists)
        XCTAssertTrue(thursday.label.contains("7:49"))
        XCTAssertEqual(thursday.value as? String, "")

        thursday.press(forDuration: 1.2)
        let skip = app.buttons["Skip this day"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        attach("week-long-press")
        skip.tap()
        XCTAssertTrue(thursday.waitForExistence(timeout: 5))
        XCTAssertEqual(thursday.value as? String, "Skipped")
        attach("week-thursday-skipped")

        thursday.press(forDuration: 1.2)
        let restore = app.buttons["Restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(thursday.waitForExistence(timeout: 5))
        XCTAssertEqual(thursday.value as? String, "")
    }

    @MainActor
    func testTappingADayShowsItOnTheArc() {
        let app = launch()
        XCTAssertTrue(app.buttons["bell.sunrise"].waitForExistence(timeout: 20))
        app.swipeUp()
        let day = app.buttons["week.day.2026-10-01"]
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()

        let back = app.buttons["preview.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "time.sunrise").label, "7:49")
        XCTAssertEqual(element(app, "time.sunset").label, "19:29")
        attach("arc-thursday")

        back.tap()
        XCTAssertTrue(element(app, "countdown").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "time.sunrise").label, "7:47")
    }

    @MainActor
    func testSettingsTogglesMirrorTheBells() {
        let app = launch()
        openSettings(app)
        let sunrise = app.switches["settings.sunrise"]
        XCTAssertTrue(labelled(app, containing: "7:47 · every day").exists)
        XCTAssertTrue(labelled(app, containing: "19:33 · every day").exists)
        attach("settings")
        XCTAssertEqual(sunrise.value as? String, "1")
        sunrise.tap()
        XCTAssertEqual(sunrise.value as? String, "0")

        attach("settings-sunrise-off")
        // Back up with the Digital Crown: Settings, 7 days, Today.
        for _ in 0..<12 where !app.buttons["bell.sunrise"].isHittable {
            XCUIDevice.shared.rotateDigitalCrown(delta: -1.5, velocity: 2)
        }
        attach("back-on-main")
        XCTAssertTrue(app.buttons["bell.sunrise"].isHittable)
        XCTAssertEqual(app.buttons["bell.sunrise"].value as? String, "Off")
        XCTAssertEqual(app.buttons["bell.sunset"].value as? String, "On")
    }

    @MainActor
    func testLocationScreenShowsTheCityOffline() {
        let app = launch()
        openSettings(app)
        let row = element(app, "settings.location")
        // The row is further down the list.
        for _ in 0..<4 where !(row.exists && row.isHittable) {
            app.swipeUp(velocity: .slow)
        }
        attach("settings-bottom")
        XCTAssertTrue(row.isHittable)
        row.tap()

        XCTAssertTrue(element(app, "location.place").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "location.place").label, "Paris, France")
        XCTAssertTrue(element(app, "location.status").label.hasPrefix("GPS"))
        XCTAssertTrue(app.buttons["location.refresh"].exists)
        attach("location")
    }

    // MARK: - System permission

    /// Goes through the real notification prompt, on the real clock, so that the alarms are
    /// actually scheduled. Tools/check_notifications.sh then reads how many are pending.
    @MainActor
    func testGrantingNotificationsFromOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-horizonReset", "YES", "-horizonLocation", "48.8566,2.3522", "-horizonTimeZone", "Europe/Paris",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"
        ]
        app.launch()
        let action = app.buttons["onboarding.action"]
        XCTAssertTrue(action.waitForExistence(timeout: 20))
        action.tap()
        XCTAssertTrue(app.staticTexts["Where are you?"].waitForExistence(timeout: 5))
        action.tap()
        XCTAssertTrue(app.staticTexts["Never miss it"].waitForExistence(timeout: 5))
        action.tap()

        // The prompt belongs to the system, not to the app. It only shows the first time.
        let allow = XCUIApplication(bundleIdentifier: "com.apple.Carousel").buttons["Allow"]
        if allow.waitForExistence(timeout: 8) {
            attach("system-notification-prompt")
            allow.tap()
        }

        XCTAssertTrue(app.staticTexts["Your alarms"].waitForExistence(timeout: 10))
        app.swipeUp()
        action.tap()
        XCTAssertTrue(element(app, "pill").waitForExistence(timeout: 5))
    }
}

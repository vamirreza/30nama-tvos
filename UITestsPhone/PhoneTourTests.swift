import XCTest

/// Touch-driven checks for the iPhone app. Shots go to $SHOT_DIR.
/// `testLoginSheet` needs a signed-out app; `testSignedInTour` needs a signed-in one.
final class PhoneTourTests: XCTestCase {
    private var shots: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory() + "sinama-phone-shots", isDirectory: true)
    }

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)
    }

    private func shot(_ name: String, wait: TimeInterval = 2) {
        Thread.sleep(forTimeInterval: wait)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: shots.appendingPathComponent("\(name).png"))
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    private func tab(_ app: XCUIApplication, _ label: String) {
        let b = app.tabBars.buttons[label]
        if b.waitForExistence(timeout: 5) { b.tap() }
    }

    func testLoginSheet() throws {
        let app = launchApp()
        let login = app.buttons["ورود با سی‌نما"]
        guard login.waitForExistence(timeout: 20) else { throw XCTSkip("Already signed in") }
        shot("p01-login")
        login.tap()
        shot("p02-safari-sheet", wait: 15)
    }

    func testSignedInTour() throws {
        let app = launchApp()
        guard app.tabBars.buttons["خانه"].waitForExistence(timeout: 40) else { throw XCTSkip("Signed out") }
        shot("p10-home", wait: 6)
        app.swipeUp(); shot("p11-home-scrolled")
        app.swipeDown()

        tab(app, "جستجو"); shot("p12-search")
        tab(app, "دسته‌بندی"); shot("p13-browse", wait: 3)
        tab(app, "لیست من"); shot("p14-mylist", wait: 3)
        tab(app, "حساب"); shot("p15-account", wait: 3)

        // Title page from the hero's Details button.
        tab(app, "خانه")
        if app.buttons["جزئیات"].waitForExistence(timeout: 5) {
            app.buttons["جزئیات"].tap()
            shot("p16-title", wait: 4)
            app.swipeUp(); shot("p17-title-scrolled")
        }
    }

    /// Plays a title through search so no tab-specific layout is needed to find it.
    func testPlayback() throws {
        let app = launchApp()
        guard app.tabBars.buttons["جستجو"].waitForExistence(timeout: 40) else { throw XCTSkip("Signed out") }
        tab(app, "جستجو")
        let field = app.searchFields.firstMatch
        guard field.waitForExistence(timeout: 5) else { return }
        field.tap()
        field.typeText("Avengers")
        shot("p20-search-results", wait: 4)
        app.scrollViews.firstMatch.buttons.firstMatch.tap()
        shot("p21-title", wait: 4)
        if app.buttons["پخش"].exists { app.buttons["پخش"].tap() }
        else if app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'ادامه'")).firstMatch.exists {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'ادامه'")).firstMatch.tap()
        }
        shot("p22-player", wait: 12)
        app.tap()
        shot("p23-player-chrome", wait: 1)
    }
}

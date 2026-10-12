import XCTest

/// Drives the app with Siri Remote presses and saves screenshots, so layout and focus can be
/// checked without a hand on the remote. Run with `xcodebuild test`; shots go to $SHOT_DIR.
final class TourTests: XCTestCase {
    private let remote = XCUIRemote.shared
    private var shots: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory() + "sinama-shots", isDirectory: true)
    }

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)
    }

    private func shot(_ name: String, wait: TimeInterval = 2.5) {
        Thread.sleep(forTimeInterval: wait)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: shots.appendingPathComponent("\(name).png"))
    }

    private func press(_ b: XCUIRemote.Button, _ times: Int = 1, pause: TimeInterval = 0.6) {
        for _ in 0..<times { remote.press(b); Thread.sleep(forTimeInterval: pause) }
    }

    func testTour() {
        let app = XCUIApplication()
        app.launchArguments += ["-30nama.language", "fa"]
        app.launch()
        shot("01-home", wait: 6)

        // Tab bar is a row at the top; Persian layout puts Home on the right, so "right" goes back.
        press(.up, 3)
        press(.left)   // search
        shot("02-search-tab")
        press(.select)
        shot("03-search-open")
        press(.menu)

        press(.left)   // categories
        press(.select)
        shot("04-browse")
        press(.menu)

        press(.left)   // my list
        press(.select)
        shot("05-mylist")
        press(.menu)

        press(.left)   // notifications
        press(.select)
        shot("06-notifications")
        press(.menu)

        press(.left)   // account
        press(.select)
        shot("07-account")
        press(.menu)
    }

    func testTitleAndPlayer() {
        let app = XCUIApplication()
        app.launchArguments += ["-30nama.language", "fa"]
        app.launch()
        shot("10-home", wait: 6)
        // Down from the tab bar lands on the hero's Play button; Details is one step toward the left.
        press(.down)
        press(.left)
        shot("11-hero-focus")
        press(.select)
        shot("12-title", wait: 6)
        press(.select) // Play is focused on the title page
        shot("14-player-start", wait: 10)
        shot("15-player-playing", wait: 8)
        press(.playPause)
        shot("16-player-paused")
        press(.down)
        shot("17-player-menu")
    }

    /// Plays the first Continue Watching title, which is known to stream for this account.
    func testContinueWatching() {
        let app = XCUIApplication()
        app.launchArguments += ["-30nama.language", "fa"]
        app.launch()
        shot("20-home", wait: 6)
        press(.down, 2)          // hero actions, then the first row (rightmost poster in RTL)
        shot("21-row-focus")
        press(.select)
        shot("22-title", wait: 6)
        press(.select)           // Play / Resume
        shot("23-player-start", wait: 10)
        shot("24-player-playing", wait: 10)
        press(.down)
        shot("25-player-controls")
        press(.menu)
        shot("26-after-menu", wait: 3)
    }

    /// Plays a resumable title, samples frames for subtitles, then walks the transport-bar menus.
    func testPlayerFeatures() {
        let app = XCUIApplication()
        app.launchArguments += ["-30nama.language", "fa"]
        app.launch()
        shot("30-home", wait: 6)
        press(.down, 2)
        press(.select)
        shot("31-player", wait: 12)
        // Subtitles only show during dialogue, so sample a few moments.
        for i in 0..<4 { shot("32-sub-\(i)", wait: 12) }
        // Skip ahead with the remote to reach other scenes.
        press(.right, 3, pause: 1.0)
        shot("33-after-seek", wait: 6)
        press(.down)
        shot("34-controls", wait: 1)
        for i in 0..<4 {
            press(.right)
            shot("35-focus-\(i)", wait: 1)
        }
        press(.select)
        shot("36-menu-open", wait: 1.5)
        press(.menu)
        press(.menu)
        shot("37-closed", wait: 3)
    }

    /// Starts the first Continue Watching title and leaves it alone, so playback state can be inspected.
    func testPlayUntouched() {
        let app = XCUIApplication()
        app.launchArguments += ["-30nama.language", "fa"]
        app.launch()
        shot("40-home", wait: 6)
        press(.down, 2)
        press(.select)
        shot("41-player", wait: 30)
    }
}

//
//  StorePreviewWalkthrough.swift
//  TweliUITests
//
//  Drives the app for the App Store preview VIDEO. Not a test of anything — it
//  asserts almost nothing on purpose — it is a marionette, run while
//  `xcrun simctl io <udid> recordVideo` films the simulator.
//
//  WHY A UI TEST AND NOT A SCRIPT
//
//  Apple requires an app preview to be footage of the app in use, so a montage
//  of the still screenshots would be the wrong artefact even if it looked
//  identical. Actual taps are needed, and `simctl` cannot inject them — the
//  note about that in this repo is about simctl, not about XCUITest, which runs
//  inside the simulator and synthesises real touches. This is the only
//  mechanism here that can produce a legitimate preview.
//
//  WHY THE PAUSES ARE SO LONG
//
//  A preview autoplays muted and has 15-30 seconds to be understood by someone
//  who has never seen the app. Taps at test speed are unreadable on film. Every
//  `beat` below is a deliberate hold so a viewer can finish reading the screen
//  before it changes. The total is tuned to land inside 30s AFTER the launch
//  and splash are trimmed off the front.
//
//  RUN
//    xcrun simctl io <udid> recordVideo --codec h264 out.mov &
//    xcodebuild test ... -only-testing:TweliUITests/StorePreviewWalkthrough
//    (then stop the recording and cut to 886x1920 — see scripts note)
//

import XCTest

final class StorePreviewWalkthrough: XCTestCase {

    /// Reading time for one screen, in seconds. Tuned for silent autoplay.
    private let beat: UInt32 = 2

    override func setUpWithError() throws {
        continueAfterFailure = true   // a missing element must not cut the film short
    }

    @MainActor
    func testWalkthrough() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            // Tutorial first, then straight into a signed-in populated space —
            // one continuous session, no relaunch mid-film.
            "TWELI_TUTORIAL_PAGE": "0",
            "TWELI_SKIP_ONBOARDING": "1",
            "TWELI_CAPTURE": "1",
            // Permission dialogs are system UI: they would sit on top of the
            // footage and Apple requires previews to show only the app.
            "TWELI_NO_LOCATION_ASK": "1",
        ]
        app.launch()

        // The splash runs ~4.5s. Wait it out rather than racing it; the front of
        // the recording gets trimmed anyway.
        let next = app.buttons["Next"]
        _ = next.waitForExistence(timeout: 20)

        // --- Onboarding: four pages, the last button reads differently --------
        for _ in 0..<3 {
            guard next.exists else { break }
            sleep(beat)
            next.tap()
        }
        sleep(beat)

        let start = app.buttons["Start your thread"]
        if start.waitForExistence(timeout: 5) {
            start.tap()
        } else if app.buttons["Skip"].exists {
            // Fallback so the film still reaches the app if the copy changes.
            app.buttons["Skip"].tap()
        }

        // --- Home: the payoff screen. Hold longest here ----------------------
        let home = app.tabBars.buttons["Home"]
        _ = home.waitForExistence(timeout: 20)
        sleep(beat + 2)

        // --- The globe, if the strip is reachable ----------------------------
        // Guarded: the closeness strip has no stable identifier, so this is
        // best-effort and must never abort the walkthrough.
        let strip = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'apart'")).firstMatch
        if strip.exists {
            strip.tap()
            sleep(beat + 2)
            let close = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons.element(boundBy: 0)
            if close.exists { close.tap() }
            sleep(1)
        }

        // --- The three other tabs --------------------------------------------
        for tab in ["Moods", "Reminders", "Letters"] {
            let button = app.tabBars.buttons[tab]
            guard button.exists else { continue }
            button.tap()
            sleep(beat)
        }

        // End back where a viewer should remember the app: the shared space.
        if home.exists {
            home.tap()
            sleep(beat)
        }
    }
}

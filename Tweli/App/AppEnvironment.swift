//
//  AppEnvironment.swift
//  Tweli
//
//  Build-environment flags.
//
//  This app ships with ZERO seeded data. There is no mock/demo content anywhere
//  in the codebase — every service starts empty and fills only from real synced
//  records, so a fresh install shows the comp's genuine empty states (E5, E7)
//  rather than a populated screen.
//
//  The one remaining hook below is DEBUG-only and seeds no content whatsoever:
//  it flips the onboarding-complete flags so a headless simulator can reach the
//  main tabs for screenshots, since CI simulators cannot inject the taps that
//  onboarding requires.
//

import Foundation

enum AppEnvironment {

#if DEBUG
    /// Verification hook (DEBUG only, compiled out of every distribution build).
    /// Launched with `TWELI_SKIP_ONBOARDING=1` — e.g.
    /// `SIMCTL_CHILD_TWELI_SKIP_ONBOARDING=1 xcrun simctl launch …` — this marks
    /// first-run setup as done so the app opens on the main tabs.
    ///
    /// It writes NO content: no moods, reminders, letters, dates or partner. The
    /// app lands on Home in its true empty state. Must run before any service
    /// reads UserDefaults, so call it from `TweliApp.init()`.
    /// How far through first-run setup the launch override should skip. Each
    /// stage stops one screen short of the next, so a headless capture can land
    /// on the profile flow (X1–X6) or the join screen (J1–J5) — neither of which
    /// is reachable once everything is marked done.
    private enum Stage: String {
        case profile   // signed in, tutorial done, profile flow NOT done  → X1–X6
        case room      // profile done, no space yet                       → RoomSetup / J1–J5
        case tabs      // everything done, empty space                     → MainTabView
    }

    static func applyLaunchOverridesIfNeeded() {
        let env = ProcessInfo.processInfo.environment
        let d = UserDefaults.standard

        // Capturing the tutorial means forcing its gate back OPEN. It is shown
        // once per install, so without this the second capture onwards lands
        // wherever the previous launch left the app.
        if env["TWELI_TUTORIAL_PAGE"] != nil {
            d.set(false, forKey: TutorialGate.key)
            return
        }

        guard env["TWELI_SKIP_ONBOARDING"] == "1" else { return }

        // TWELI_STAGE=profile|room|tabs. Absent means `tabs`, which is what
        // every existing capture script already expects.
        let stage = Stage(rawValue: env["TWELI_STAGE"] ?? "") ?? .tabs

        // Every flag is written explicitly, true OR false. Only setting the
        // ones a stage needs leaves the others at whatever the last launch
        // wrote — and `simctl spawn defaults delete` does not reliably clear
        // them, so a stale `aboutYouDone` silently skips the screen under test.
        // Authoritative writes make each launch independent of history.
        d.set(true, forKey: TutorialGate.key)
        if d.string(forKey: "tweli.auth.appleUserId") == nil {
            d.set("dev-\(UUID().uuidString)", forKey: "tweli.auth.appleUserId")
        }

        d.set(stage != .profile, forKey: "tweli.aboutYouDone")
        d.set(stage == .tabs, forKey: "tweli.roomSetupComplete")

        if stage == .tabs {
            // An empty space so the tab bar is reachable. This is app STATE, not
            // content: no partner, no moods, no reminders, no letters, no dates —
            // which is exactly the comp's E5 "half a thread" state.
            if d.data(forKey: "tweli.coupleSpace") == nil {
                let space = CoupleSpace(title: "Our space",
                                        createdBy: UUID(),
                                        partnerIds: [])
                if let data = try? JSONEncoder().encode(space) {
                    d.set(data, forKey: "tweli.coupleSpace")
                }
            }
        } else {
            // `isConnected` is `coupleSpace != nil`, so a leftover space would
            // route straight past the profile flow and the join screen.
            d.removeObject(forKey: "tweli.coupleSpace")
        }
    }
#endif
}

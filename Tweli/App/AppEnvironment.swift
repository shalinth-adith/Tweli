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
    static func applyLaunchOverridesIfNeeded() {
        let env = ProcessInfo.processInfo.environment
        guard env["TWELI_SKIP_ONBOARDING"] == "1" else { return }
        let d = UserDefaults.standard
        d.set(true, forKey: "tweli.aboutYouDone")
        d.set(true, forKey: "tweli.roomSetupComplete")
        if d.string(forKey: "tweli.auth.appleUserId") == nil {
            d.set("dev-\(UUID().uuidString)", forKey: "tweli.auth.appleUserId")
        }
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
    }
#endif
}

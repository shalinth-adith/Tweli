//
//  AppEnvironment.swift
//  Tweli
//
//  Single source of truth for "is this a developer build showing demo data?".
//
//  Two guarantees for a no-compromise production build:
//   1. `useDemoData` is compiled to a constant `false` in any non-DEBUG build
//      (Release / TestFlight / App Store) — the demo path is unreachable.
//   2. Even in DEBUG it is OFF by default. A developer must explicitly opt in
//      (SignIn "dev mode" button or the Debug-only Settings toggle). So a plain
//      Debug run also boots into the real, clean onboarding.
//

import Foundation

enum AppEnvironment {
    private static let demoKey = "tweli.dev.demoData"

    /// True only when: this is a DEBUG build AND a developer explicitly enabled
    /// demo data. Always `false` in a distribution build.
    static var useDemoData: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: demoKey)
        #else
        return false
        #endif
    }

    /// Turn demo/mock data on (DEBUG only — a no-op in distribution builds).
    static func enableDemoData() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: demoKey)
        #endif
    }

    /// Turn demo/mock data off.
    static func disableDemoData() {
        UserDefaults.standard.set(false, forKey: demoKey)
    }

#if DEBUG
    /// Verification hook (DEBUG only, absent from distribution builds). When the
    /// app is launched with `TWELI_DEMO=1` in its environment — e.g.
    /// `SIMCTL_CHILD_TWELI_DEMO=1 xcrun simctl launch …` — seed the fully
    /// connected demo state so a headless build boots straight to Home instead of
    /// onboarding (which needs taps the CI simulator can't perform). Add
    /// `TWELI_FRESH_MOOD=1` to also surface the inline fresh-mood card by clearing
    /// the acknowledged baseline. Must run before any service reads UserDefaults,
    /// so call it from `TweliApp.init()`.
    static func applyLaunchOverridesIfNeeded() {
        let env = ProcessInfo.processInfo.environment
        guard env["TWELI_DEMO"] == "1" else { return }
        let d = UserDefaults.standard
        d.set(true, forKey: demoKey)                        // seed MockData
        d.set(true, forKey: "tweli.aboutYouDone")           // skip "About you"
        d.set(true, forKey: "tweli.roomSetupComplete")      // pre-connected space
        if d.string(forKey: "tweli.auth.appleUserId") == nil {
            d.set("dev-\(UUID().uuidString)", forKey: "tweli.auth.appleUserId")
        }
        // Fresh → clear the baseline so the interstitial raises over Home;
        // otherwise mark the mock mood already seen so Home shows the calm
        // resting card with no interstitial.
        if env["TWELI_FRESH_MOOD"] == "1" {
            d.set(Date(timeIntervalSince1970: 0), forKey: "tweli.mood.lastSeenPartner")
        } else {
            d.set(Date(), forKey: "tweli.mood.lastSeenPartner")
        }
    }
#endif
}

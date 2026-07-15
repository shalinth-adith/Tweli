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
}

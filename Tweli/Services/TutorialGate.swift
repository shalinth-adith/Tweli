//
//  TutorialGate.swift
//  Tweli
//
//  Whether the comp 0Z entry tutorial has already been shown on this device.
//
//  Small enough to have been an inline `UserDefaults.standard.bool(...)` in
//  AppViewModel, and it was — but "does this really only appear once?" is not a
//  question anyone should have to answer by reinstalling the app and watching.
//  As its own type it can be unit-tested against a scratch suite, including the
//  part that actually matters: that a SECOND read, on a fresh instance, sees
//  what the first one wrote.
//
//  Device-level, not account-level. It teaches the app rather than describing
//  the account, so `AppViewModel.resetLocalState()` deliberately leaves it
//  alone — deleting your account should not mean sitting through the intro
//  again on the way back in.
//

import Foundation

struct TutorialGate {

    static let key = "tweli.tutorialSeen"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// False on a genuinely fresh install, and only then.
    var hasSeen: Bool { defaults.bool(forKey: Self.key) }

    /// Skip and "Start your thread" both land here — both mean "never again".
    func markSeen() {
        defaults.set(true, forKey: Self.key)
    }
}

//
//  TutorialGateTests.swift
//  TweliTests
//
//  "It should only appear on a fresh install" is the whole contract of the
//  entry tutorial, and it is the one thing you cannot check by looking at a
//  screenshot — every launch during development is a fresh install, which is
//  exactly the case where it SHOULD appear. These tests cover the case that
//  screenshots cannot: the second launch.
//

import Testing
import Foundation
@testable import Tweli

@Suite("Tutorial gate")
struct TutorialGateTests {

    private func scratch(_ name: String) -> UserDefaults {
        let suite = "tweli.tests.tutorial.\(name)"
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    // 1 — HAPPY: fresh install shows it; every launch after that does not.
    @Test("happy: shown on a fresh install, never again after finishing")
    func shownOnceThenNeverAgain() {
        let d = scratch("once")

        // Launch 1 — nothing stored yet.
        #expect(TutorialGate(defaults: d).hasSeen == false)

        // User taps Skip or "Start your thread".
        TutorialGate(defaults: d).markSeen()

        // Launches 2..n — a NEW gate instance each time, as on a real relaunch.
        for _ in 0..<5 {
            #expect(TutorialGate(defaults: d).hasSeen,
                    "the tutorial reappeared on a later launch")
        }
    }

    // 2 — the flag must survive being written by one instance and read by
    // another; an instance-local cache would pass test 1 by accident.
    @Test("the flag is persisted, not held in memory")
    func flagIsPersisted() {
        let d = scratch("persist")
        TutorialGate(defaults: d).markSeen()

        // A separate suite object over the same domain — as close to a process
        // restart as a unit test gets.
        let reopened = UserDefaults(suiteName: "tweli.tests.tutorial.persist")!
        #expect(TutorialGate(defaults: reopened).hasSeen)
    }

    // 3 — marking twice is harmless (Skip on page 3 after Next on 1 and 2).
    @Test("marking seen is idempotent")
    func markingIsIdempotent() {
        let d = scratch("idempotent")
        let gate = TutorialGate(defaults: d)
        gate.markSeen()
        gate.markSeen()
        #expect(gate.hasSeen)
    }

    // 4 — a genuinely fresh install (empty domain) must show it again. This is
    // the behaviour that makes reinstall-to-test work, and it is easy to break
    // by defaulting the flag to true.
    @Test("a fresh install shows it again")
    func freshInstallShowsAgain() {
        let d = scratch("fresh")
        TutorialGate(defaults: d).markSeen()
        #expect(TutorialGate(defaults: d).hasSeen)

        // Reinstall == the domain is gone.
        UserDefaults.standard.removePersistentDomain(forName: "tweli.tests.tutorial.fresh")
        let reinstalled = UserDefaults(suiteName: "tweli.tests.tutorial.fresh")!
        #expect(TutorialGate(defaults: reinstalled).hasSeen == false)
    }

    // 5 — the key the debug launch hook writes must be the key the gate reads.
    // AppEnvironment sets this string literally; a rename would silently break
    // every headless screenshot run.
    @Test("the persisted key matches the launch-override contract")
    func keyContract() {
        #expect(TutorialGate.key == "tweli.tutorialSeen")
    }
}

//
//  ReinstallGateTests.swift
//  TweliTests
//
//  "Was the app deleted and put back?" is answered by two stores that fail
//  differently — the Keychain survives an uninstall, UserDefaults does not — and
//  it is precisely the question you cannot check by running the app. Every
//  launch during development looks like a first install, which is the one case
//  where the reinstall flow must NOT appear.
//
//  These tests simulate the uninstall the only way that is meaningful: by
//  clearing the defaults half and leaving the Keychain half alone.
//

import Testing
import Foundation
@testable import Tweli

@Suite("Reinstall gate")
struct ReinstallGateTests {

    private func scratch(_ name: String) -> UserDefaults {
        let suite = "tweli.tests.reinstall.\(name)"
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    /// What iOS does on delete: the container goes, the Keychain stays.
    private func uninstall(_ defaults: UserDefaults, _ name: String) {
        defaults.removePersistentDomain(forName: "tweli.tests.reinstall.\(name)")
    }

    // 1 — HAPPY: nothing stored anywhere is a genuine first launch.
    @Test("happy: a clean device is a first install")
    func cleanDeviceIsFirstInstall() {
        let gate = ReinstallGate(defaults: scratch("first"), store: InMemoryKeychain())
        #expect(gate.launch == .firstInstall)
    }

    // 2 — HAPPY: the second launch of the same install is ordinary. This is the
    // common case and the one that must never light up the K screens.
    @Test("happy: relaunching the same install is not a reinstall")
    func secondLaunchIsOrdinary() {
        let defaults = scratch("second")
        let keychain = InMemoryKeychain()

        ReinstallGate(defaults: defaults, store: keychain).markInstalled()

        let relaunch = ReinstallGate(defaults: defaults, store: keychain)
        #expect(relaunch.launch == .sameInstall)
    }

    // 3 — THE CASE THAT MATTERS: delete, reinstall. The Keychain remembers,
    // the container does not.
    @Test("delete and reinstall is detected, and remembers whether we were paired")
    func reinstallIsDetected() {
        let name = "reinstall"
        var defaults = scratch(name)
        let keychain = InMemoryKeychain()

        let first = ReinstallGate(defaults: defaults, store: keychain)
        first.markInstalled()
        first.markPaired()

        uninstall(defaults, name)
        defaults = UserDefaults(suiteName: "tweli.tests.reinstall.\(name)")!

        let afterReinstall = ReinstallGate(defaults: defaults, store: keychain)
        #expect(afterReinstall.launch == .reinstall(hadPair: true))
    }

    // 4 — EDGE: reinstalled, but never paired. Same detection, different answer,
    // and the difference decides between comp K5 and Start-or-join.
    @Test("edge: reinstall without ever pairing reports hadPair false")
    func reinstallWithoutPairing() {
        let name = "unpaired"
        var defaults = scratch(name)
        let keychain = InMemoryKeychain()

        ReinstallGate(defaults: defaults, store: keychain).markInstalled()

        uninstall(defaults, name)
        defaults = UserDefaults(suiteName: "tweli.tests.reinstall.\(name)")!

        #expect(ReinstallGate(defaults: defaults, store: keychain).launch
                == .reinstall(hadPair: false))
    }

    // 5 — REGRESSION: `markInstalled()` must never downgrade `hadPair`. It runs
    // on EVERY launch including the reinstall itself, so an implementation that
    // overwrote the record would erase the pairing history at exactly the moment
    // the K5 routing depends on it.
    @Test("regression: marking installed again does not forget the pairing")
    func markInstalledPreservesPairing() {
        let name = "preserve"
        var defaults = scratch(name)
        let keychain = InMemoryKeychain()

        let first = ReinstallGate(defaults: defaults, store: keychain)
        first.markInstalled()
        first.markPaired()

        uninstall(defaults, name)
        defaults = UserDefaults(suiteName: "tweli.tests.reinstall.\(name)")!

        let afterReinstall = ReinstallGate(defaults: defaults, store: keychain)
        let classified = afterReinstall.launch      // read BEFORE marking, as AppViewModel does
        afterReinstall.markInstalled()

        #expect(classified == .reinstall(hadPair: true))
        // And the record still says paired, for the launch after this one.
        uninstall(defaults, name)
        defaults = UserDefaults(suiteName: "tweli.tests.reinstall.\(name)")!
        #expect(ReinstallGate(defaults: defaults, store: keychain).launch
                == .reinstall(hadPair: true))
    }

    // 6 — EDGE: deleting the account wipes the marker, so the next install is a
    // genuine first install. Without this a brand-new user on a recycled device
    // would be greeted with "welcome back" — and, worse, routed to K5.
    @Test("edge: forgetting the account resets to a first install")
    func forgetResets() {
        let defaults = scratch("forget")
        let keychain = InMemoryKeychain()

        let gate = ReinstallGate(defaults: defaults, store: keychain)
        gate.markInstalled()
        gate.markPaired()
        gate.forget()

        #expect(ReinstallGate(defaults: defaults, store: keychain).launch == .firstInstall)
    }
}

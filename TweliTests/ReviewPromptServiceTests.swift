//
//  ReviewPromptServiceTests.swift
//  TweliTests
//
//  The rating prompt's decision logic. Worth testing rather than eyeballing,
//  because every wrong "yes" is unrecoverable: iOS caps the prompt at three per
//  user per year and reports nothing when it swallows one, so a bug here is
//  invisible in production.
//
//  Each test runs against its own scratch UserDefaults suite, and creates a
//  SECOND service instance to stand in for a later app launch — the session
//  boundary is captured at init.
//

import Testing
import Foundation
@testable import Tweli

@MainActor
@Suite("Review prompt")
struct ReviewPromptServiceTests {

    /// A throwaway defaults domain per test, so nothing leaks between cases or
    /// into the real app domain.
    private func scratch(_ name: String) -> UserDefaults {
        let suite = "tweli.tests.review.\(name)"
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    // 1 — HAPPY: a happy moment arms, and the prompt fires on the NEXT launch.
    @Test("happy: armed in one session, fires in the next")
    func firesInLaterSession() {
        let d = scratch("happy")

        let launch1 = ReviewPromptService(defaults: d)
        launch1.arm(.letterOpened)
        #expect(launch1.isArmed)

        // Same session must not fire — first entry already spends two system
        // permission modals, and a third stacked dialog gets all three declined.
        var shownInSameSession = false
        launch1.fireIfArmed { shownInSameSession = true }
        #expect(shownInSameSession == false)
        #expect(launch1.isArmed, "a suppressed fire must not disarm")

        // A later launch is a new session.
        let launch2 = ReviewPromptService(defaults: d)
        var shownLater = false
        launch2.fireIfArmed { shownLater = true }
        #expect(shownLater)
        #expect(launch2.isArmed == false, "firing disarms")
    }

    // 2 — the same build never asks twice, however many moments occur.
    @Test("never prompts twice on the same version")
    func onePromptPerVersion() {
        let d = scratch("version")

        let launch1 = ReviewPromptService(defaults: d)
        launch1.arm(.partnered)
        let launch2 = ReviewPromptService(defaults: d)
        #expect(launch2.fireIfArmed { })

        // A second happy moment on the same build must not even arm.
        launch2.arm(.letterOpened)
        #expect(launch2.isArmed == false)

        let launch3 = ReviewPromptService(defaults: d)
        var shown = false
        launch3.fireIfArmed { shown = true }
        #expect(shown == false)
    }

    // 3 — pairing is a one-shot. The space-doc listener reports the partner's
    // name on EVERY sync, so the guard has to live in the service.
    @Test("partner-present is one-shot across repeated syncs")
    func partnerPresentIsOneShot() {
        let d = scratch("partner")

        let launch1 = ReviewPromptService(defaults: d)
        #expect(launch1.hasEverPartnered == false)
        launch1.notePartnerPresent()
        #expect(launch1.hasEverPartnered)
        #expect(launch1.isArmed)

        // Fire it, then keep syncing — no re-arm.
        let launch2 = ReviewPromptService(defaults: d)
        #expect(launch2.fireIfArmed { })
        for _ in 0..<5 { launch2.notePartnerPresent() }
        #expect(launch2.isArmed == false)
    }

    // 4 — a second moment must not overwrite the first arming timestamp, or a
    // moment that keeps re-occurring could hold the prompt off forever.
    @Test("re-arming keeps the earliest moment")
    func armingIsIdempotent() {
        let d = scratch("idempotent")

        let s = ReviewPromptService(defaults: d)
        s.arm(.partnered)
        let firstArmedAt = d.object(forKey: "tweli.review.armedAt") as? Date
        s.arm(.letterOpened)
        let afterArmedAt = d.object(forKey: "tweli.review.armedAt") as? Date

        #expect(firstArmedAt == afterArmedAt)
        #expect(d.string(forKey: "tweli.review.armedReason") == ReviewPromptService.Moment.partnered.rawValue)
    }

    // 5 — nothing armed means nothing fires, no matter how many launches.
    @Test("unarmed never fires")
    func unarmedNeverFires() {
        let d = scratch("unarmed")
        for _ in 0..<3 {
            let s = ReviewPromptService(defaults: d)
            var shown = false
            s.fireIfArmed { shown = true }
            #expect(shown == false)
        }
    }
}

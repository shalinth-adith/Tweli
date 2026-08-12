//
//  ReviewPromptService.swift
//  Tweli
//
//  Asks for an App Store rating — but only at a moment that has actually earned
//  one, and only a couple of times in the app's life.
//
//  Two constraints shape this design:
//
//  1. iOS silently caps the rating prompt at three appearances per user per 365
//     days. Calls past the cap do nothing AND report nothing, so a prompt fired
//     at a mediocre moment is not merely ignored — it burns one of the three
//     and you never find out. Every call has to be spent deliberately.
//
//  2. The best moments emotionally (the partner finally joining, opening a
//     letter that was written for you) are also the busiest moments visually.
//     Dropping a system modal on top of a reveal animation reads as an
//     interruption and costs the goodwill the moment just created.
//
//  So this is arm-then-fire: a happy moment ARMS the prompt, and it FIRES at
//  the next calm point — Home, settled, a beat after the animation is done.
//

import Foundation
import Combine
import StoreKit
import SwiftUI

@MainActor
final class ReviewPromptService: ObservableObject {

    /// The moments considered worth spending a prompt on.
    enum Moment: String {
        /// The partner accepted the invite and the space became a pair. The
        /// single highest-joy second in the product.
        case partnered
        /// An open-when letter was opened — written by their person, for them.
        case letterOpened
    }

    private let defaults: UserDefaults

    /// `defaults` is injectable so tests can run against a scratch suite instead
    /// of the real domain, and so a fresh instance can stand in for a fresh
    /// launch (see `sessionStartedAt`).
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let armed        = "tweli.review.armedReason"
        static let armedAt      = "tweli.review.armedAt"
        static let lastVersion  = "tweli.review.lastPromptedVersion"
        static let lastDate     = "tweli.review.lastPromptedAt"
        static let everPartnered = "tweli.review.everPartnered"
    }

    /// When this launch began. A prompt never fires in the same session that
    /// armed it — partly to let the happy moment breathe, but mostly because
    /// first entry into a session already spends two system modals on
    /// notification and location permission (see MainTabView.task). A third
    /// stacked dialog is how you get declined on all three.
    private let sessionStartedAt = Date()

    /// Never ask the same build twice, and leave a long gap between asks even
    /// across builds. Well under Apple's 3-per-year ceiling on purpose: we would
    /// rather leave a call unspent than spend it on a lukewarm moment.
    private static let minimumDaysBetweenPrompts = 120.0

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    // MARK: - Pairing (one-shot)

    /// True once this device has ever seen a second person in the space. Used to
    /// tell "the partner just joined" from "the partner joined months ago and we
    /// are relaunching" — the space-doc listener cannot distinguish those, since
    /// it reports the partner's name on every sync.
    var hasEverPartnered: Bool { defaults.bool(forKey: Key.everPartnered) }

    /// Call whenever the space reports a partner. Arms the prompt only on the
    /// genuine first transition into a pair.
    func notePartnerPresent() {
        guard !hasEverPartnered else { return }
        defaults.set(true, forKey: Key.everPartnered)
        arm(.partnered)
    }

    // MARK: - Arming

    func arm(_ moment: Moment) {
        guard canPrompt else { return }          // don't arm what we can't fire
        guard !isArmed else { return }           // keep the earliest arming moment
        defaults.set(moment.rawValue, forKey: Key.armed)
        defaults.set(Date(), forKey: Key.armedAt)
    }

    var isArmed: Bool { defaults.string(forKey: Key.armed) != nil }

    /// Armed in an earlier session, so the moment has had time to land.
    private var armedInAnEarlierSession: Bool {
        guard let armedAt = defaults.object(forKey: Key.armedAt) as? Date else {
            return true   // armed before this key existed — treat as ready
        }
        return armedAt < sessionStartedAt
    }

    /// Eligibility, independent of whether anything is armed.
    private var canPrompt: Bool {
        if defaults.string(forKey: Key.lastVersion) == currentVersion { return false }
        if let last = defaults.object(forKey: Key.lastDate) as? Date {
            let days = Date().timeIntervalSince(last) / 86_400
            if days < Self.minimumDaysBetweenPrompts { return false }
        }
        return true
    }

    // MARK: - Firing

    /// Fire a previously-armed prompt, if it is still allowed. Safe to call on
    /// every Home appearance; it no-ops unless something armed it.
    ///
    /// `request` is SwiftUI's `\.requestReview` action — passed in rather than
    /// captured so this stays a plain service with no view dependency.
    func fireIfArmed(_ request: RequestReviewAction) {
        fireIfArmed { request() }
    }

    /// Core of the above, taking the presentation as a closure so the decision
    /// logic can be tested without a `RequestReviewAction` (which cannot be
    /// constructed outside SwiftUI). Returns true when the prompt was shown.
    @discardableResult
    func fireIfArmed(_ present: () -> Void) -> Bool {
        guard isArmed else { return false }
        guard canPrompt else {
            // Stale arm (e.g. armed on an older build that then prompted) —
            // clear it so it can't fire at a random later moment.
            clearArm()
            return false
        }
        guard armedInAnEarlierSession else { return false }   // let the moment breathe

        clearArm()
        defaults.set(currentVersion, forKey: Key.lastVersion)
        defaults.set(Date(), forKey: Key.lastDate)
        present()
        return true
    }

    private func clearArm() {
        defaults.removeObject(forKey: Key.armed)
        defaults.removeObject(forKey: Key.armedAt)
    }
}

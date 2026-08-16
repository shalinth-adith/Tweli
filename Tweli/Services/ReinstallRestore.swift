//
//  ReinstallRestore.swift
//  Tweli
//
//  The shapes behind comps K1–K5 — the flow a returning user walks after
//  deleting the app and putting it back.
//
//  These are plain values with no Firebase or SwiftUI in them, which is the
//  point: the decisions worth being sure about (what counts as "restored", when
//  it is fair to say a partner left, whether there is any cleanup to show) are
//  testable without a network, a simulator, or a signed-in account.
//
//  Nothing here invents a number. Every count is derived from records already
//  synced onto the device, so K3's "24 reminders · 6 open" is the same 24 the
//  user sees on the next screen — not a plausible-looking stand-in.
//

import Foundation

// MARK: - Where the flow is

/// The reinstall flow's position, owned by AppViewModel and routed on by
/// RootView. `.none` covers both "this is an ordinary launch" and "the flow has
/// finished", because RootView treats them identically.
enum RestorePhase: Equatable {
    case none
    /// K1 — the welcome-back front door. Same Apple button, different promise.
    case signIn
    /// K2 — the thread redrawing itself. This IS the loading state; there is no
    /// separate spinner in front of it.
    case restoring
    /// K3 — proof of what came back.
    case rejoined
    /// K4 — the only two things iOS actually wiped.
    case cleanup
    /// K5 — signed in, but there is no pair to return to.
    case pairGone
}

// MARK: - K2

/// One row of K2's checklist.
struct RestoreStep: Identifiable, Equatable {
    enum State: Equatable {
        case waiting     // hollow ring
        case running     // spinner
        case done        // filled check
        case skipped     // nothing of this kind existed; still honest to show
    }

    let id: String
    var title: String
    /// The trailing figure — "214 days", "18 of 24". Nil until it is known;
    /// never a placeholder.
    var detail: String?
    var state: State = .waiting
}

// MARK: - K3

/// What actually came back, counted from the local store after the listeners
/// have delivered their first snapshot.
struct RestoreSummary: Equatable {
    var partnerName: String
    var pairedDays: Int?

    var reminders = 0
    var openReminders = 0
    var letters = 0
    var sealedLetters = 0
    /// The partner's current mood label, if they have shared one.
    var partnerMood: String?
    var plannedDates = 0
    var nextDate: Date?

    /// True when the space is real but empty — a pair that had not written
    /// anything yet. K3 then drops its stat rows rather than printing four
    /// zeroes, which reads as a failed restore when nothing failed.
    var isEmpty: Bool {
        reminders == 0 && letters == 0 && plannedDates == 0 && partnerMood == nil
    }
}

// MARK: - K5

/// Enough to tell somebody their pair is gone without guessing at any of it.
struct PairGoneDetail: Equatable {
    /// Nil when the space itself is gone (swept after both sides went quiet),
    /// in which case there is no name on record and K5 says so rather than
    /// naming somebody it cannot name.
    var partnerName: String?
    var leftAt: Date?
    var lettersKept = 0
    var remindersKept = 0

    var hasKeepsakes: Bool { lettersKept > 0 || remindersKept > 0 }
}

// MARK: - K4

/// The two things deleting the app genuinely takes away, and nothing else.
///
/// Both are checked against the system rather than assumed. A user who
/// reinstalled and re-added their widget before opening the app should not be
/// told their widget is missing — the screen would be describing a state that
/// does not exist, which is the same class of bug as a fabricated placeholder.
struct ReinstallCleanup: Equatable {
    var widgetMissing = false
    var notificationsOff = false

    /// Nothing to do — K4 is skipped entirely and the user goes straight in.
    var isEmpty: Bool { !widgetMissing && !notificationsOff }
}

// MARK: - Counting

/// Builds K3's summary and K5's keepsake counts from records already on the
/// device. Free functions on a caseless enum so they can be tested directly.
enum RestoreCounting {

    static func summary(partnerName: String,
                        pairedDays: Int?,
                        reminders: [ReminderItem],
                        letters: [OpenWhenLetter],
                        partnerMood: MoodStatus?,
                        dates: [VirtualDateItem],
                        now: Date = Date()) -> RestoreSummary {
        var summary = RestoreSummary(partnerName: partnerName, pairedDays: pairedDays)

        summary.reminders = reminders.count
        // "Open" is anything still waiting on somebody — a missed reminder is
        // very much still open, and a snoozed one has only been postponed.
        summary.openReminders = reminders.filter { $0.status != .completed }.count

        summary.letters = letters.count
        summary.sealedLetters = letters.filter { $0.isLocked }.count

        summary.partnerMood = partnerMood?.displayLabel

        let upcoming = dates
            .filter { $0.status == .planned && $0.date >= now }
            .sorted { $0.date < $1.date }
        summary.plannedDates = upcoming.count
        summary.nextDate = upcoming.first?.date

        return summary
    }

    /// K5's "kept for you". Only what survives a partner's departure: the
    /// letters they sealed for you (the leave function deliberately leaves those
    /// behind) and the reminders the two of you finished. Everything they
    /// authored and left open went with them, so it is not counted here.
    static func keepsakes(partnerName: String?,
                          leftAt: Date?,
                          reminders: [ReminderItem],
                          letters: [OpenWhenLetter]) -> PairGoneDetail {
        PairGoneDetail(partnerName: partnerName,
                       leftAt: leftAt,
                       lettersKept: letters.count,
                       remindersKept: reminders.filter { $0.status == .completed }.count)
    }
}

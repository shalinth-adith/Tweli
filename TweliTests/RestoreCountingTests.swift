//
//  RestoreCountingTests.swift
//  TweliTests
//
//  Comp K3 exists to be evidence — "you're still with them, and here is what
//  came back". Evidence that is quietly wrong is worse than no evidence, and
//  these figures are the kind that look right in a screenshot while being off by
//  one: a completed reminder counted as open, a sealed letter counted as
//  readable, yesterday's date offered as the next one.
//
//  Nothing here needs Firestore, a simulator, or an account, which is why the
//  counting lives in `RestoreCounting` rather than inline in the view.
//

import Testing
import Foundation
@testable import Tweli

@Suite("Restore counting")
struct RestoreCountingTests {

    private let me = UUID()
    private let space = UUID()

    private func reminder(_ title: String, _ status: ReminderStatus) -> ReminderItem {
        var item = ReminderItem(title: title, createdBy: me, coupleSpaceId: space,
                                reminderDate: Date())
        item.status = status
        return item
    }

    private func letter(sealedUntil: Date?) -> OpenWhenLetter {
        OpenWhenLetter(title: "Open when", message: "…",
                       createdBy: me, coupleSpaceId: space,
                       unlockDate: sealedUntil)
    }

    private func date(_ offsetDays: Int, _ status: VirtualDateStatus) -> VirtualDateItem {
        var item = VirtualDateItem(title: "Call",
                                   date: Date().addingTimeInterval(Double(offsetDays) * 86_400),
                                   coupleSpaceId: space, createdBy: me)
        item.status = status
        return item
    }

    // 1 — HAPPY: a populated space, counted the way K3 prints it.
    @Test("happy: every figure matches the records it was counted from")
    func countsMatchRecords() {
        let summary = RestoreCounting.summary(
            partnerName: "Sam",
            pairedDays: 214,
            reminders: [reminder("a", .completed), reminder("b", .pending), reminder("c", .missed)],
            letters: [letter(sealedUntil: nil),
                      letter(sealedUntil: Date().addingTimeInterval(86_400))],
            partnerMood: nil,
            dates: [date(3, .planned), date(9, .planned), date(-2, .planned)])

        #expect(summary.reminders == 3)
        // Missed and snoozed are still open — somebody is still waiting on them.
        #expect(summary.openReminders == 2)
        #expect(summary.letters == 2)
        #expect(summary.sealedLetters == 1)
        // The date two days in the PAST is not "planned" in any useful sense.
        #expect(summary.plannedDates == 2)
        #expect(summary.pairedDays == 214)
        #expect(!summary.isEmpty)
    }

    // 2 — EDGE: a real pair that had not written anything yet. K3 must be able
    // to tell this apart from a failed restore, because it renders differently:
    // four zeroed rows read as "nothing came back".
    @Test("edge: an empty space reports empty rather than four zeroes")
    func emptySpaceIsEmpty() {
        let summary = RestoreCounting.summary(
            partnerName: "Sam", pairedDays: 2,
            reminders: [], letters: [], partnerMood: nil, dates: [])

        #expect(summary.isEmpty)
        #expect(summary.reminders == 0)
    }

    // 3 — EDGE: the next date is the SOONEST upcoming one, not the first in the
    // array. Firestore returns documents unordered, so relying on array order
    // would show whichever date happened to sync first.
    @Test("edge: nextDate is the soonest upcoming, not the first stored")
    func nextDateIsSoonest() {
        let far = date(30, .planned)
        let soon = date(2, .planned)
        let summary = RestoreCounting.summary(
            partnerName: "Sam", pairedDays: nil,
            reminders: [], letters: [], partnerMood: nil,
            dates: [far, soon])

        #expect(summary.nextDate == soon.date)
    }

    // 4 — EDGE: cancelled dates are not planned ones.
    @Test("edge: cancelled and completed dates are not counted as planned")
    func onlyPlannedDatesCount() {
        let summary = RestoreCounting.summary(
            partnerName: "Sam", pairedDays: nil,
            reminders: [], letters: [], partnerMood: nil,
            dates: [date(4, .planned), date(5, .cancelled), date(6, .completed)])

        #expect(summary.plannedDates == 1)
    }

    // 5 — K5: "kept for you" counts only what actually survives a departure.
    // The leave function deletes the leaver's open items but deliberately leaves
    // their sealed letters behind, and finished reminders are shared history.
    @Test("K5: keepsakes count kept letters and finished reminders only")
    func keepsakesCountWhatSurvives() {
        let detail = RestoreCounting.keepsakes(
            partnerName: "Sam",
            leftAt: nil,
            reminders: [reminder("a", .completed), reminder("b", .completed),
                        reminder("c", .pending)],
            letters: [letter(sealedUntil: nil), letter(sealedUntil: nil)])

        #expect(detail.remindersKept == 2)
        #expect(detail.lettersKept == 2)
        #expect(detail.hasKeepsakes)
    }

    // 6 — REGRESSION: nothing kept must report nothing kept. K5 swaps its
    // primary action on this — offering "Read what's kept" over an empty space
    // is a dead end, and the button would be lying about there being something
    // to read.
    @Test("regression: no keepsakes reports none, so K5 drops the read action")
    func noKeepsakes() {
        let detail = RestoreCounting.keepsakes(partnerName: nil, leftAt: nil,
                                               reminders: [reminder("a", .pending)],
                                               letters: [])
        #expect(!detail.hasKeepsakes)
    }
}

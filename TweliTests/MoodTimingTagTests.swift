//
//  MoodTimingTagTests.swift
//  TweliTests
//
//  The timing tag on the Home mood card exists to answer one question — "is this
//  how they feel NOW, or how they felt on Tuesday?" — and it is the kind of
//  string that looks correct in every screenshot taken on the day it was
//  written. A bare "8:12 AM" on a three-day-old mood is not a rounding error; it
//  actively claims freshness the record does not have.
//
//  Every case below pins `now` explicitly, so these do not start failing at
//  midnight or in a different timezone.
//

import Testing
import Foundation
@testable import Tweli

@Suite("Mood timing tag")
struct MoodTimingTagTests {

    /// A fixed calendar and clock, so "today" means the same thing on every
    /// machine that runs this.
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    private func at(_ year: Int, _ month: Int, _ day: Int,
                    _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: hour, minute: minute))!
    }

    /// Friday 16 August 2026, 10:34 — the moment comp L3 is drawn at.
    private var now: Date { at(2026, 8, 16, 10, 34) }

    private func tag(_ date: Date) -> String {
        MoodStatus.timingTag(for: date, now: now, calendar: calendar)
    }

    // 1 — HAPPY: the case the comp draws. Same day ⇒ time only.
    @Test("happy: a mood set earlier today shows just the time")
    func todayShowsTimeOnly() {
        let result = tag(at(2026, 8, 16, 8, 12))
        // Locale decides "8:12 AM" vs "08:12"; what matters is that neither a
        // day name nor a date leaked in.
        #expect(result.contains("8"))
        #expect(!result.contains("Yesterday"))
        #expect(!result.contains("Aug"))
    }

    // 2 — HAPPY: a mood posted seconds ago reads as now, not as a clock time.
    @Test("happy: a mood from seconds ago reads Just now")
    func secondsAgoIsJustNow() {
        #expect(tag(now.addingTimeInterval(-20)) == "Just now")
    }

    // 3 — BOUNDARY: one minute is where the clock time takes over.
    @Test("boundary: the Just now window ends at sixty seconds")
    func justNowBoundary() {
        #expect(tag(now.addingTimeInterval(-59)) == "Just now")
        #expect(tag(now.addingTimeInterval(-61)) != "Just now")
    }

    // 4 — THE BUG THIS PREVENTS: 8:12 AM yesterday must not read as 8:12 AM.
    // Same clock time, completely different meaning, and the un-laddered version
    // rendered them identically.
    @Test("yesterday is named, so it cannot be mistaken for this morning")
    func yesterdayIsNamed() {
        let result = tag(at(2026, 8, 15, 8, 12))
        #expect(result.hasPrefix("Yesterday"))
        #expect(result.contains("8"))
    }

    // 5 — EDGE: within the week, a weekday is easier to place than a date.
    @Test("edge: earlier this week shows the weekday")
    func weekdayWithinTheWeek() {
        let result = tag(at(2026, 8, 12, 20, 5))   // Wednesday, 4 days earlier
        #expect(result.contains("Wed"))
        #expect(!result.contains("Aug"))
    }

    // 6 — EDGE: past a week, a weekday is ambiguous ("Wed" — which one?), so it
    // becomes a date.
    @Test("edge: older than a week shows a date, not a weekday")
    func dateBeyondTheWeek() {
        let result = tag(at(2026, 7, 30, 9, 0))
        #expect(result.contains("Jul"))
        #expect(!result.contains("Yesterday"))
    }

    // 7 — REGRESSION: the partner's phone can be a few seconds ahead of ours,
    // which makes `updatedAt` land in the future. Rendering a future clock time
    // on a card that says "how they feel right now" reads as a broken app.
    @Test("regression: a timestamp from the future degrades to Just now")
    func futureTimestampDoesNotRenderAhead() {
        #expect(tag(now.addingTimeInterval(45)) == "Just now")
        #expect(tag(now.addingTimeInterval(3_600)) == "Just now")
    }

    // 8 — The model wires the tag to `updatedAt`, not `id` or a create date. A
    // re-shared mood should read as fresh, because it is.
    @Test("the tag follows updatedAt, so re-sharing a mood reads as fresh")
    func tagFollowsUpdatedAt() {
        var mood = MoodStatus(userId: UUID(), mood: .missingYou)
        mood.updatedAt = Date()
        #expect(mood.timingTag == "Just now")
    }
}

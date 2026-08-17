//
//  PartnerDepartureCopyTests.swift
//  TweliTests
//
//  Comps M4 and M5 both open with a phrase about WHEN something happened, and
//  both are the kind of string that looks right in the screenshot taken the day
//  it was written. "this morning" on a departure from three weeks ago is not a
//  cosmetic slip — it is the screen inventing a fact.
//
//  Every case pins `now` explicitly, following MoodTimingTagTests: a test that
//  only passes on the day it was written is not testing anything. Both functions
//  under test measure against the `now` they are GIVEN, never the system clock,
//  which is what makes that pinning possible. Do not reintroduce
//  `Calendar.isDateInToday` into either of them.
//

import Testing
import Foundation
@testable import Tweli

@Suite("Partner departure copy")
struct PartnerDepartureCopyTests {

    /// Fixed calendar and clock, so these mean the same thing on every machine.
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: - M4: "They closed their side <phrase>"

    @Test("A departure earlier today reads by part of day, not by clock time")
    func sameDayPartsOfDay() {
        let now = at(2026, 8, 17, 21, 30)
        #expect(PartnerLeftView.whenPhrase(for: at(2026, 8, 17, 9), now: now, calendar: cal)
                == "this morning")
        #expect(PartnerLeftView.whenPhrase(for: at(2026, 8, 17, 14), now: now, calendar: cal)
                == "this afternoon")
        #expect(PartnerLeftView.whenPhrase(for: at(2026, 8, 17, 19), now: now, calendar: cal)
                == "this evening")
    }

    /// Midnight and noon are the boundaries most likely to be written as `<=`.
    @Test("Part-of-day boundaries land on the right side")
    func partOfDayBoundaries() {
        let now = at(2026, 8, 17, 23, 59)
        #expect(PartnerLeftView.whenPhrase(for: at(2026, 8, 17, 0), now: now, calendar: cal)
                == "this morning")
        #expect(PartnerLeftView.whenPhrase(for: at(2026, 8, 17, 11, 59), now: now, calendar: cal)
                == "this morning")
        #expect(PartnerLeftView.whenPhrase(for: at(2026, 8, 17, 12), now: now, calendar: cal)
                == "this afternoon")
        #expect(PartnerLeftView.whenPhrase(for: at(2026, 8, 17, 16, 59), now: now, calendar: cal)
                == "this afternoon")
        #expect(PartnerLeftView.whenPhrase(for: at(2026, 8, 17, 17), now: now, calendar: cal)
                == "this evening")
    }

    /// The bug this guards: an 11pm departure and a 1am "now" are 2 hours apart
    /// but MUST NOT read "this evening" — the day rolled over.
    @Test("Just after midnight, last night is yesterday")
    func acrossMidnight() {
        let now = at(2026, 8, 18, 1)
        #expect(PartnerLeftView.whenPhrase(for: at(2026, 8, 17, 23), now: now, calendar: cal)
                == "yesterday")
    }

    @Test("Within the week counts days; beyond it, a date")
    func olderDepartures() {
        let now = at(2026, 8, 17, 12)
        #expect(PartnerLeftView.whenPhrase(for: at(2026, 8, 14, 12), now: now, calendar: cal)
                == "3 days ago")
        #expect(PartnerLeftView.whenPhrase(for: at(2026, 8, 11, 12), now: now, calendar: cal)
                == "6 days ago")
        // A week out stops counting: "7 days ago" invites arithmetic nobody wants
        // to do on this screen.
        let old = PartnerLeftView.whenPhrase(for: at(2026, 7, 20, 12), now: now, calendar: cal)
        #expect(!old.contains("days ago"))
        #expect(old.contains("20"))
    }

    // MARK: - M5: "Their side has been quiet since <phrase>"

    /// M5 is built on a dead push token, which is NOT proof of an uninstall.
    /// These assert the phrasing stays coarse — the screen may say when it went
    /// quiet, never how long to the hour, and never why.
    @Test("Quiet phrasing is coarse and never claims a reason")
    func quietPhrasing() {
        let now = at(2026, 8, 17, 12)
        #expect(PartnerQuietView.quietPhrase(for: at(2026, 8, 17, 3), now: now, calendar: cal)
                == "today")
        #expect(PartnerQuietView.quietPhrase(for: at(2026, 8, 16, 3), now: now, calendar: cal)
                == "yesterday")
        #expect(PartnerQuietView.quietPhrase(for: at(2026, 8, 13, 3), now: now, calendar: cal)
                == "4 days ago")

        for days in 0...30 {
            let then = cal.date(byAdding: .day, value: -days, to: now)!
            let phrase = PartnerQuietView.quietPhrase(for: then, now: now, calendar: cal)
            #expect(!phrase.lowercased().contains("delete"))
            #expect(!phrase.lowercased().contains("uninstall"))
            #expect(!phrase.lowercased().contains("left"))
        }
    }

    /// A stamp fractionally in the future (server clock skew is real) must not
    /// produce a negative count.
    @Test("Clock skew never yields a negative day count")
    func futureStampIsSafe() {
        let now = at(2026, 8, 17, 12)
        let skewed = at(2026, 8, 17, 13)
        #expect(PartnerQuietView.quietPhrase(for: skewed, now: now, calendar: cal) == "today")
        #expect(PartnerLeftView.whenPhrase(for: skewed, now: now, calendar: cal)
                == "this afternoon")
    }
}

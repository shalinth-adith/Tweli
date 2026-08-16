//
//  MoodStatus.swift
//  Tweli
//

import Foundation

/// A partner's current shared mood — reduces misunderstanding at a distance.
struct MoodStatus: Identifiable, Codable, Hashable, LocallyAuthored {
    var id: UUID = UUID()
    var userId: UUID
    var mood: PartnerMood
    /// A free-text mood the user typed instead of picking a preset (designs 24a/b).
    /// When non-empty it is what the partner sees; `mood` still backs the tint /
    /// SF Symbol on legacy surfaces (widget). nil/empty ⇒ a plain preset mood.
    var customText: String? = nil
    var note: String? = nil
    var updatedAt: Date = Date()

    /// What the partner actually reads: the typed mood if present, else the preset
    /// label. Every mood surface (home card, interstitial, strip) shows this.
    var displayLabel: String {
        if let t = customText?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        return mood.label
    }

    var relativeLabel: String {
        updatedAt.formatted(.relative(presentation: .named))
    }

    /// The timing tag on the Home mood card — comps L3 / N3 put it at the right
    /// of the "From <partner>" eyebrow, reading "8:12 AM".
    var timingTag: String { Self.timingTag(for: updatedAt) }

    /// Rendered in the READER's local zone, not the author's.
    ///
    /// That is the iOS convention and it matches every other timestamp in the
    /// app, but it is worth being explicit about in a long-distance app where
    /// the two phones disagree about what time it is. The question "what time is
    /// it where they are?" is already answered by the partner-local-time banner
    /// that sits directly above this card; this line answers a different one —
    /// "how long ago did this land on MY phone?"
    ///
    /// The comp only draws the same-day case. The rest of the ladder exists
    /// because a bare "8:12 AM" on a three-day-old mood is not a small
    /// imprecision — it actively says the mood is fresh when it isn't, which is
    /// the exact confusion the tag was added to remove.
    static func timingTag(for date: Date,
                          now: Date = Date(),
                          calendar: Calendar = .current) -> String {
        let elapsed = now.timeIntervalSince(date)

        // A negative interval means the author's clock is ahead of ours. Showing
        // a future time would read as broken; "Just now" is both harmless and
        // very nearly true.
        if elapsed < 60 { return "Just now" }

        // Every style is built FROM the passed calendar. `date.formatted(…)`
        // silently uses the device's calendar and zone instead, which made the
        // comparisons above and the string below disagree about what day it was
        // — "today" by one clock, printed with the hour from another.
        let base = Date.FormatStyle(locale: calendar.locale ?? .autoupdatingCurrent,
                                    calendar: calendar,
                                    timeZone: calendar.timeZone)
        let time = date.formatted(base.hour(.defaultDigits(amPM: .abbreviated)).minute())

        if calendar.isDateInToday(date) { return time }                  // "8:12 AM" — the comp
        if calendar.isDateInYesterday(date) { return "Yesterday \(time)" }

        // Inside the last week a weekday is easier to place than a date.
        if let days = calendar.dateComponents([.day],
                                              from: calendar.startOfDay(for: date),
                                              to: calendar.startOfDay(for: now)).day,
           (0...6).contains(days) {
            return "\(date.formatted(base.weekday(.abbreviated))) \(time)"
        }

        return date.formatted(base.day().month(.abbreviated))            // "12 Aug"
    }
}

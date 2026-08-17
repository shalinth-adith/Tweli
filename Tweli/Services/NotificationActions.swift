//
//  NotificationActions.swift
//  Tweli
//
//  Comps RA3, RA6, RA7, RA8, RA9 — the actions a Tweli notification offers when
//  it is pulled open.
//
//  Everything the RA comps draw around these actions is iOS's: the lock-screen
//  card, the banner, the light and dark treatments (RAL1–RAL9). What an app
//  actually controls is three things — the copy, which category a notification
//  belongs to, and what each button does. This file owns the second and third.
//
//  Design rules taken from the comps, and worth keeping:
//
//    - A letter NEVER previews its contents on the lock screen (RA7). The body
//      is a fixed "Sealed until you open it." regardless of what was written.
//    - A completion echo is silent — no sound, no badge (RA5). It is a courtesy,
//      not a demand.
//    - Overdue nudges once and stops (RA6). The partner is not told you missed it.
//    - Mood changes arrive silently and never repeat (RA8).
//

import Foundation
import UserNotifications

enum TweliNotification {

    // MARK: - Categories

    enum Category {
        static let reminder = "tweli.reminder"          // RA3
        static let reminderOverdue = "tweli.reminder.overdue"  // RA6
        static let letter = "tweli.letter"              // RA7
        static let mood = "tweli.mood"                  // RA8
        static let date = "tweli.date"                  // RA9
        static let completion = "tweli.completion"      // RA5 — no actions
        static let left = "tweli.left"                  // M1/M2 — no actions
    }

    // MARK: - Actions

    enum Action {
        static let markDone = "tweli.action.markDone"
        static let snooze = "tweli.action.snooze"
        static let replyToPartner = "tweli.action.reply"
        static let openLetter = "tweli.action.openLetter"
        static let saveLetterForTonight = "tweli.action.saveLetter"
        static let sendLoveBack = "tweli.action.sendLove"
        static let checkIn = "tweli.action.checkIn"
        static let dateAccept = "tweli.action.dateAccept"
        static let dateSuggestAnother = "tweli.action.dateSuggest"
    }

    /// The whole set, registered once at launch.
    ///
    /// iOS shows at most four actions on a pulled-open notification, so each
    /// category is kept to the comp's own count rather than padded.
    static var categories: Set<UNNotificationCategory> {
        // RA3 — "Mark done", "Snooze 15 min", "Reply to Anaya"
        let reminder = UNNotificationCategory(
            identifier: Category.reminder,
            actions: [
                UNNotificationAction(identifier: Action.markDone, title: "Mark done",
                                     options: []),
                UNNotificationAction(identifier: Action.snooze, title: "Snooze 15 min",
                                     options: []),
                UNTextInputNotificationAction(identifier: Action.replyToPartner,
                                              title: "Reply",
                                              options: [],
                                              textInputButtonTitle: "Send",
                                              textInputPlaceholder: "Tell them why…"),
            ],
            intentIdentifiers: [], options: [])

        // RA6 — one nudge, two ways out. Deliberately shorter than RA3: an
        // overdue card is not the moment to offer a conversation.
        let overdue = UNNotificationCategory(
            identifier: Category.reminderOverdue,
            actions: [
                UNNotificationAction(identifier: Action.markDone, title: "Done", options: []),
                UNNotificationAction(identifier: Action.snooze, title: "Snooze", options: []),
            ],
            intentIdentifiers: [], options: [])

        // RA7 — "Open letter" / "Save for tonight". Opening is foreground
        // because a sealed letter should be read, not dismissed in a swipe.
        let letter = UNNotificationCategory(
            identifier: Category.letter,
            actions: [
                UNNotificationAction(identifier: Action.openLetter, title: "Open letter",
                                     options: [.foreground]),
                UNNotificationAction(identifier: Action.saveLetterForTonight,
                                     title: "Save for tonight", options: []),
            ],
            intentIdentifiers: [], options: [])

        // RA8 — "❤️" / "Check in on her"
        let mood = UNNotificationCategory(
            identifier: Category.mood,
            actions: [
                UNNotificationAction(identifier: Action.sendLoveBack, title: "❤️", options: []),
                UNNotificationAction(identifier: Action.checkIn, title: "Check in",
                                     options: [.foreground]),
            ],
            intentIdentifiers: [], options: [])

        // RA9 — "I'm in" / "Suggest another time"
        let date = UNNotificationCategory(
            identifier: Category.date,
            actions: [
                UNNotificationAction(identifier: Action.dateAccept, title: "I'm in", options: []),
                UNNotificationAction(identifier: Action.dateSuggestAnother,
                                     title: "Suggest another time", options: [.foreground]),
            ],
            intentIdentifiers: [], options: [])

        // RA5 — a completion echo carries no actions. There is nothing to do
        // about someone else finishing something.
        let completion = UNNotificationCategory(
            identifier: Category.completion, actions: [],
            intentIdentifiers: [], options: [])

        // M1 / M2 — a partner leaving the thread carries no actions either, for
        // a different reason than RA5. There IS something to do about it, but
        // every option (read their letters, start a new thread) is a decision
        // that deserves the M4 screen and its context — not a button pressed
        // half-awake from a lock screen.
        let left = UNNotificationCategory(
            identifier: Category.left, actions: [],
            intentIdentifiers: [], options: [])

        return [reminder, overdue, letter, mood, date, completion, left]
    }

    // MARK: - Copy (comps RA1–RA9)

    /// RA1: "Anaya reminded you" when they set it, "You set this" when you did.
    static func reminderTitle(mine: Bool, partnerName: String) -> String {
        mine ? "You set this" : "\(displayName(partnerName)) reminded you"
    }

    /// RA6. Amber, silent, and it stops there.
    static func overdueTitle(partnerName: String) -> String {
        "Still open from \(displayName(partnerName))"
    }

    /// RA5. Comes back quietly.
    static func completionTitle(partnerName: String) -> String {
        "\(displayName(partnerName)) got it done"
    }

    /// RA7. The body never previews the letter — that is the whole point of a
    /// sealed letter, and a lock screen is the worst place to break it.
    static let letterBody = "Sealed until you open it."
    static func letterTitle(partnerName: String) -> String {
        "\(displayName(partnerName)) sent you a letter"
    }

    /// RA8.
    static func moodTitle(partnerName: String, mood: String) -> String {
        "\(displayName(partnerName)) is feeling \(mood.lowercased())"
    }

    /// RA9.
    static func dateTitle(partnerName: String) -> String {
        "\(displayName(partnerName)) planned a date"
    }

    private static func displayName(_ name: String) -> String {
        let t = name.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "Your partner" : t
    }
}

// MARK: - Snooze options (comp RA4)

/// RA4's four choices. The comp's promise — "Anaya will see the new time" — is
/// why these resolve to a concrete `Date` rather than a vague delay: the new
/// time is written to the shared reminder, so it is genuinely visible to both.
enum SnoozeOption: String, CaseIterable, Identifiable {
    case fifteenMinutes, anHour, beforeBed, tomorrowMorning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fifteenMinutes:   return "In 15 minutes"
        case .anHour:           return "In an hour"
        case .beforeBed:        return "Before bed"
        case .tomorrowMorning:  return "Tomorrow morning"
        }
    }

    /// The wall-clock time this resolves to, from a given "now".
    func date(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .fifteenMinutes:
            return now.addingTimeInterval(15 * 60)
        case .anHour:
            return now.addingTimeInterval(60 * 60)
        case .beforeBed:
            // 11:30 PM today, or tomorrow if that has already passed.
            return Self.next(hour: 23, minute: 30, from: now, calendar: calendar)
        case .tomorrowMorning:
            return Self.next(hour: 8, minute: 0, from: now, calendar: calendar,
                             preferTomorrow: true)
        }
    }

    /// The subtitle the comp shows beside each option ("9:15 PM", "10:00 PM"…).
    func subtitle(from now: Date = Date(), calendar: Calendar = .current) -> String {
        date(from: now, calendar: calendar)
            .formatted(date: .omitted, time: .shortened)
    }

    private static func next(hour: Int, minute: Int, from now: Date,
                             calendar: Calendar, preferTomorrow: Bool = false) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        guard let today = calendar.date(from: comps) else { return now.addingTimeInterval(3600) }
        if preferTomorrow || today <= now {
            return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        }
        return today
    }
}

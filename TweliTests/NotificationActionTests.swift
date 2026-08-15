//
//  NotificationActionTests.swift
//  TweliTests
//
//  Comps RA3–RA9. Almost none of this is visually verifiable: iOS draws the
//  lock-screen card and the banner, and a simulator cannot long-press one. What
//  CAN be pinned is everything that decides what those cards say and what their
//  buttons do — the category registration, the identifier→intent mapping, the
//  copy, and the snooze arithmetic. That is what these cover.
//
//  The one thing to keep in mind reading them: an action that maps to no intent
//  is silently inert on the device. There is no crash and no log — the button
//  simply does nothing. So the mapping tests matter more than they look.
//

import Testing
import Foundation
import UserNotifications
@testable import Tweli

@Suite("Notification actions")
struct NotificationActionTests {

    // MARK: - Categories (RA3, RA6, RA7, RA8, RA9)

    private func category(_ id: String) -> UNNotificationCategory? {
        TweliNotification.categories.first { $0.identifier == id }
    }

    @Test("every comp's category is registered")
    func allCategoriesExist() {
        for id in [TweliNotification.Category.reminder,
                   TweliNotification.Category.reminderOverdue,
                   TweliNotification.Category.letter,
                   TweliNotification.Category.mood,
                   TweliNotification.Category.date,
                   TweliNotification.Category.completion] {
            #expect(category(id) != nil, "missing category \(id)")
        }
    }

    /// iOS shows at most four actions on a pulled-open notification. Exceeding
    /// that silently truncates — the last button just never appears.
    @Test("no category exceeds what iOS will display")
    func actionCountsAreWithinLimits() {
        for c in TweliNotification.categories {
            #expect(c.actions.count <= 4, "\(c.identifier) has \(c.actions.count) actions")
        }
    }

    @Test("RA3 offers done, snooze and a text reply")
    func reminderCategoryMatchesComp() throws {
        let c = try #require(category(TweliNotification.Category.reminder))
        let ids = c.actions.map(\.identifier)
        #expect(ids.contains(TweliNotification.Action.markDone))
        #expect(ids.contains(TweliNotification.Action.snooze))
        #expect(ids.contains(TweliNotification.Action.replyToPartner))
        // "Reply to Anaya" has to accept typing, not just open the app.
        let reply = c.actions.first { $0.identifier == TweliNotification.Action.replyToPartner }
        #expect(reply is UNTextInputNotificationAction)
    }

    /// RA6 is deliberately shorter than RA3 — an overdue card is not the moment
    /// to offer a conversation.
    @Test("RA6 offers only the two ways out")
    func overdueCategoryIsShort() throws {
        let c = try #require(category(TweliNotification.Category.reminderOverdue))
        #expect(c.actions.count == 2)
    }

    /// RA5's own note: nothing to do about someone else finishing something.
    @Test("a completion echo carries no actions")
    func completionHasNoActions() throws {
        let c = try #require(category(TweliNotification.Category.completion))
        #expect(c.actions.isEmpty)
    }

    /// Opening a sealed letter should bring the app forward, not happen behind
    /// a swipe.
    @Test("opening a letter is a foreground action")
    func openLetterIsForeground() throws {
        let c = try #require(category(TweliNotification.Category.letter))
        let open = try #require(c.actions.first { $0.identifier == TweliNotification.Action.openLetter })
        #expect(open.options.contains(.foreground))
    }

    // MARK: - Identifier → intent

    private let anId = UUID()

    @Test("each action identifier maps to the intent that does the work")
    func actionsMapToIntents() throws {
        func intent(_ action: String, text: String? = nil) -> NotificationActionIntent? {
            NotificationActionIntent(actionId: action, reminderId: anId, text: text)
        }

        guard case .markReminderDone(let a)? = intent(TweliNotification.Action.markDone)
        else { Issue.record("markDone did not map"); return }
        #expect(a == anId)

        guard case .snoozeReminder(let b)? = intent(TweliNotification.Action.snooze)
        else { Issue.record("snooze did not map"); return }
        #expect(b == anId)

        guard case .openLetters? = intent(TweliNotification.Action.openLetter)
        else { Issue.record("openLetter did not map"); return }

        guard case .sendLoveBack? = intent(TweliNotification.Action.sendLoveBack)
        else { Issue.record("sendLove did not map"); return }

        guard case .acceptDate? = intent(TweliNotification.Action.dateAccept)
        else { Issue.record("dateAccept did not map"); return }
    }

    /// Mark-done and snooze are meaningless without knowing WHICH reminder. A
    /// nil id must produce no intent rather than silently acting on the wrong one.
    @Test("reminder actions require a reminder id")
    func reminderActionsNeedAnId() {
        #expect(NotificationActionIntent(actionId: TweliNotification.Action.markDone,
                                         reminderId: nil, text: nil) == nil)
        #expect(NotificationActionIntent(actionId: TweliNotification.Action.snooze,
                                         reminderId: nil, text: nil) == nil)
    }

    /// An empty reply should send nothing — posting a blank mood note would be
    /// a worse outcome than the button appearing to do nothing.
    @Test("an empty reply is not sent")
    func emptyReplyIsDropped() {
        for text in [nil, "", "   "] as [String?] {
            #expect(NotificationActionIntent(actionId: TweliNotification.Action.replyToPartner,
                                             reminderId: anId, text: text) == nil)
        }
        guard case .replyToPartner(let t)? = NotificationActionIntent(
            actionId: TweliNotification.Action.replyToPartner,
            reminderId: anId, text: "running late, sorry") else {
            Issue.record("a real reply did not map"); return
        }
        #expect(t == "running late, sorry")
    }

    @Test("dismissing does nothing, tapping the body opens the app")
    func systemIdentifiersBehave() {
        #expect(NotificationActionIntent(actionId: UNNotificationDismissActionIdentifier,
                                         reminderId: anId, text: nil) == nil)
        guard case .openApp? = NotificationActionIntent(
            actionId: UNNotificationDefaultActionIdentifier, reminderId: nil, text: nil) else {
            Issue.record("default action did not map to openApp"); return
        }
    }

    // MARK: - Copy (RA1, RA5, RA6, RA7, RA8, RA9)

    @Test("attribution flips on who set the reminder")
    func reminderTitleAttribution() {
        #expect(TweliNotification.reminderTitle(mine: true, partnerName: "Anaya") == "You set this")
        #expect(TweliNotification.reminderTitle(mine: false, partnerName: "Anaya") == "Anaya reminded you")
    }

    /// Names are user-supplied and can be blank — the copy must not read
    /// " reminded you".
    @Test("a blank partner name falls back rather than leaving a hole")
    func blankNameFallsBack() {
        #expect(TweliNotification.reminderTitle(mine: false, partnerName: "   ")
                == "Your partner reminded you")
        #expect(TweliNotification.completionTitle(partnerName: "")
                == "Your partner got it done")
    }

    /// RA7's rule, as a test: the lock-screen body is fixed and contains nothing
    /// from the letter itself.
    @Test("a letter never previews its contents")
    func letterBodyIsSealed() {
        #expect(TweliNotification.letterBody == "Sealed until you open it.")
        #expect(TweliNotification.letterTitle(partnerName: "Anaya") == "Anaya sent you a letter")
    }

    @Test("mood and date copy match the comps")
    func moodAndDateCopy() {
        #expect(TweliNotification.moodTitle(partnerName: "Anaya", mood: "Worn out")
                == "Anaya is feeling worn out")
        #expect(TweliNotification.dateTitle(partnerName: "Anaya") == "Anaya planned a date")
        #expect(TweliNotification.overdueTitle(partnerName: "Anaya") == "Still open from Anaya")
    }

    // MARK: - RA4 snooze options

    @Test("all four snooze options exist, in the comp's order")
    func snoozeOptionsMatchComp() {
        #expect(SnoozeOption.allCases.map(\.title)
                == ["In 15 minutes", "In an hour", "Before bed", "Tomorrow morning"])
    }

    @Test("relative snoozes land where they say")
    func relativeSnoozes() {
        let now = Date()
        let fifteen = SnoozeOption.fifteenMinutes.date(from: now).timeIntervalSince(now)
        let hour = SnoozeOption.anHour.date(from: now).timeIntervalSince(now)
        #expect(abs(fifteen - 15 * 60) < 1)
        #expect(abs(hour - 60 * 60) < 1)
    }

    /// "Before bed" is 11:30 PM — but if it is already midnight, the honest
    /// answer is tomorrow night, not a time that has passed.
    @Test("before bed rolls to tomorrow once it has passed")
    func beforeBedRollsForward() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        // 9:00 PM — still ahead of 11:30 PM tonight.
        let evening = try #require(cal.date(from: DateComponents(
            year: 2026, month: 8, day: 15, hour: 21, minute: 0)))
        let tonight = SnoozeOption.beforeBed.date(from: evening, calendar: cal)
        #expect(cal.component(.day, from: tonight) == 15)
        #expect(cal.component(.hour, from: tonight) == 23)

        // 11:45 PM — past it, so it must move to the next night.
        let late = try #require(cal.date(from: DateComponents(
            year: 2026, month: 8, day: 15, hour: 23, minute: 45)))
        let next = SnoozeOption.beforeBed.date(from: late, calendar: cal)
        #expect(cal.component(.day, from: next) == 16)
    }

    /// "Tomorrow morning" must always be tomorrow, even when asked at 3am — a
    /// snooze that fires in five hours is not what the user chose.
    @Test("tomorrow morning is always tomorrow")
    func tomorrowMorningIsAlwaysTomorrow() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        for hour in [3, 9, 23] {
            let now = try #require(cal.date(from: DateComponents(
                year: 2026, month: 8, day: 15, hour: hour, minute: 0)))
            let target = SnoozeOption.tomorrowMorning.date(from: now, calendar: cal)
            #expect(cal.component(.day, from: target) == 16, "failed asking at \(hour):00")
            #expect(cal.component(.hour, from: target) == 8)
            #expect(target > now)
        }
    }

    /// Every option must resolve to the future, whenever it is chosen.
    @Test("no snooze option ever resolves to the past")
    func snoozesAreAlwaysForward() {
        let now = Date()
        for option in SnoozeOption.allCases {
            #expect(option.date(from: now) > now, "\(option.title) resolved backwards")
        }
    }
}

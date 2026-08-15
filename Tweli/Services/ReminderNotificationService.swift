//
//  ReminderNotificationService.swift
//  Tweli
//
//  REAL local notifications via UserNotifications. Each reminder schedules a
//  UNCalendarNotificationTrigger keyed by the reminder's UUID so it can be
//  cancelled / rescheduled precisely. Repeats map to the right granularity.
//

import Foundation
import Combine
import UserNotifications

@MainActor
final class ReminderNotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
        // Comps RA3/RA6/RA7/RA8/RA9. Registered at launch rather than at
        // permission time: a notification that arrives before the user has
        // opened the relevant screen still needs its buttons.
        center.setNotificationCategories(TweliNotification.categories)
        refreshAuthorizationStatus()
    }

    // MARK: - Permission

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { settings in
            Task { @MainActor in self.authorizationStatus = settings.authorizationStatus }
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            refreshAuthorizationStatus()
            return granted
        } catch {
            print("[Notifications] authorization error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Scheduling

    /// - Parameters:
    ///   - mine: whether THIS device's user created the reminder. The subtitle is
    ///     written from the reader's point of view, so the same reminder says
    ///     something different on each phone.
    ///   - partnerName: used when the reader did NOT create it ("Anaya asked
    ///     you to remember this"). Falls back to "Your partner" when unknown.
    func schedule(for reminder: ReminderItem, mine: Bool, partnerName: String = "") {
        guard !reminder.isCompleted else { return }

        let who = partnerName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Your partner" : partnerName

        let content = UNMutableNotificationContent()
        // RA1: the card says who asked. `reminder.title` moves to the body so
        // the top line can carry attribution, as every RA comp shows.
        content.title = TweliNotification.reminderTitle(mine: mine, partnerName: who)
        content.subtitle = reminder.title
        content.categoryIdentifier = TweliNotification.Category.reminder
        content.userInfo["reminderId"] = reminder.id.uuidString

        // RA1's third line is the schedule — "9:00 PM · every night" — not the
        // note. A note, when there is one, is the more useful thing to read, so
        // it wins; the schedule is the fallback rather than filler.
        content.body = reminder.note.isEmpty ? scheduleLine(reminder) : reminder.note
        content.sound = .default

        // Read the reminder's time in the AUTHOR's zone to recover the wall-clock
        // components they picked ("9:30 AM"). The resulting components carry no
        // timezone, so UNCalendarNotificationTrigger fires them in THIS device's
        // local zone — i.e. 9:30 AM wherever the actor is. Same-timezone couples
        // are unaffected (authorCal == device calendar). Legacy reminders with no
        // authorTimezone fall back to the device zone (previous behavior).
        var cal = Calendar.current
        if let tzId = reminder.authorTimezone, let tz = TimeZone(identifier: tzId) {
            cal.timeZone = tz
        }
        let d = reminder.reminderDate
        let comps: DateComponents
        switch reminder.repeatType {
        case .none:
            comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        case .custom:
            // Treated as one-time until a custom-recurrence UI exists. The
            // picker no longer offers this, so it is only reached by reminders
            // synced before that change — they keep firing once, as they always
            // did, rather than silently changing behaviour under the user.
            comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        case .daily:
            comps = cal.dateComponents([.hour, .minute], from: d)
        case .weekly:
            comps = cal.dateComponents([.weekday, .hour, .minute], from: d)
        case .monthly:
            comps = cal.dateComponents([.day, .hour, .minute], from: d)
        }

        let repeats = reminder.repeatType == .daily
            || reminder.repeatType == .weekly
            || reminder.repeatType == .monthly

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString,
                                            content: content, trigger: trigger)
        center.add(request) { error in
            if let error { print("[Notifications] schedule failed: \(error.localizedDescription)") }
        }
    }

    /// One-off notification a few minutes out (used for "gentle nudge" and virtual-date reminders).
    func scheduleOneOff(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Comp X3's promise — "\(days) days away, they get a quiet nudge before" —
    /// made real. Two alerts: three days out to leave time to do something, and
    /// the morning itself.
    ///
    /// `repeats: true` on a month/day match makes these annual, so they survive
    /// without the app re-scheduling every year. Both ids are stable, so calling
    /// this on every sync replaces rather than accumulates — and passing `nil`
    /// (partner cleared their birthday, or left) removes them.
    func schedulePartnerBirthday(_ birthday: Date?, partnerName: String) {
        let ids = [Self.birthdayLeadId, Self.birthdayDayId]
        center.removePendingNotificationRequests(withIdentifiers: ids)

        guard let birthday else { return }
        let who = partnerName.trimmingCharacters(in: .whitespaces)
        let name = who.isEmpty ? "Your partner" : who

        let cal = Calendar.current
        let md = cal.dateComponents([.month, .day], from: birthday)
        guard let month = md.month, let day = md.day else { return }

        // Three days out. Built by walking back from this year's occurrence so
        // month lengths and year boundaries are the calendar's problem, not ours.
        var thisYear = DateComponents()
        thisYear.year = cal.component(.year, from: Date())
        thisYear.month = month
        thisYear.day = day
        if let occurrence = cal.date(from: thisYear),
           let lead = cal.date(byAdding: .day, value: -3, to: occurrence) {
            let l = cal.dateComponents([.month, .day], from: lead)
            scheduleAnnual(id: Self.birthdayLeadId,
                           title: "\(name)'s birthday is in 3 days",
                           body: "Time to seal a letter, or plan something small.",
                           month: l.month, day: l.day, hour: 10)
        }

        scheduleAnnual(id: Self.birthdayDayId,
                       title: "It's \(name)'s birthday 🎂",
                       body: "Say something before their day gets going.",
                       month: month, day: day, hour: 8)
    }

    private static let birthdayLeadId = "tweli.partnerBirthday.lead"
    private static let birthdayDayId  = "tweli.partnerBirthday.day"

    /// An annually-repeating calendar alert. Year is deliberately omitted — that
    /// is what makes `repeats` mean "every year" rather than "once".
    private func scheduleAnnual(id: String, title: String, body: String,
                                month: Int?, day: Int?, hour: Int) {
        guard let month, let day else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var comps = DateComponents()
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    /// Clears all pending requests — used at startup before rescheduling so mock
    /// data (whose ids change each launch) doesn't accumulate stale alerts.
    func removeAllPending() {
        center.removeAllPendingNotificationRequests()
    }

    func reschedule(for reminder: ReminderItem, mine: Bool, partnerName: String = "") {
        cancel(id: reminder.id)
        schedule(for: reminder, mine: mine, partnerName: partnerName)
    }

    // MARK: - Countdowns (fire on the day the countdown reaches zero)

    /// Schedules a one-off notification for the countdown's target day. If the
    /// target has no specific time (midnight), it fires at 9:00 AM that day.
    func scheduleCountdown(_ countdown: CountdownItem) {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: countdown.targetDate)
        let time = cal.dateComponents([.hour, .minute], from: countdown.targetDate)
        if (time.hour ?? 0) == 0 && (time.minute ?? 0) == 0 {
            comps.hour = 9; comps.minute = 0            // friendly default
        } else {
            comps.hour = time.hour; comps.minute = time.minute
        }
        guard let fire = cal.date(from: comps), fire > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = countdown.title
        content.body = countdown.arrivalMessage
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
            repeats: false)
        center.add(UNNotificationRequest(identifier: "countdown-\(countdown.id.uuidString)",
                                         content: content, trigger: trigger)) { error in
            if let error { print("[Notifications] countdown schedule failed: \(error.localizedDescription)") }
        }
    }

    func cancelCountdown(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["countdown-\(id.uuidString)"])
    }

    func rescheduleCountdown(_ countdown: CountdownItem) {
        cancelCountdown(id: countdown.id)
        scheduleCountdown(countdown)
    }

    /// For debugging / verification — how many notifications are pending.
    func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }

    // MARK: - RA1 · the schedule line

    /// "9:00 PM · every night" — the comp's third line.
    private func scheduleLine(_ reminder: ReminderItem) -> String {
        let time = reminder.localFireDate.formatted(date: .omitted, time: .shortened)
        switch reminder.repeatType {
        case .none, .custom: return time
        case .daily:         return "\(time) · every night"
        case .weekly:        return "\(time) · every week"
        case .monthly:       return "\(time) · every month"
        }
    }

    // MARK: - RA5 · the completion echo

    /// Comp RA5: "Anaya got it done". Deliberately silent — no sound, no badge.
    /// A completion is a courtesy, not a demand, and the comp's own note says
    /// completions "come back quietly … just the widget ticking over".
    func notifyCompletion(of title: String, byPartnerNamed name: String) {
        let content = UNMutableNotificationContent()
        content.title = TweliNotification.completionTitle(partnerName: name)
        content.body = title
        content.categoryIdentifier = TweliNotification.Category.completion
        content.interruptionLevel = .passive     // no sound, no wake
        // sound intentionally left nil, badge intentionally not set

        center.add(UNNotificationRequest(identifier: "tweli.completion.\(UUID().uuidString)",
                                         content: content, trigger: nil))
    }

    // MARK: - RA6 · overdue, once

    private static func overdueId(_ id: UUID) -> String { "tweli.overdue.\(id.uuidString)" }

    /// Comp RA6: one amber nudge 45 minutes after the due time, then it lets go.
    /// Scheduling is keyed by reminder id, so re-running this replaces rather
    /// than stacks — "Tweli nudges once and then lets it go."
    func scheduleOverdueNudge(for reminder: ReminderItem, partnerName: String) {
        let id = Self.overdueId(reminder.id)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        // Only for one-offs someone else set: a repeating reminder comes round
        // again by itself, and nagging about your own is just noise.
        guard !reminder.isCompleted, reminder.repeatType == .none else { return }
        let fireAt = reminder.localFireDate.addingTimeInterval(45 * 60)
        guard fireAt > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = TweliNotification.overdueTitle(partnerName: partnerName)
        content.subtitle = reminder.title
        content.body = "Due \(reminder.localFireDate.formatted(date: .omitted, time: .shortened)) · last nudge tonight"
        content.categoryIdentifier = TweliNotification.Category.reminderOverdue
        content.userInfo["reminderId"] = reminder.id.uuidString
        content.interruptionLevel = .passive     // amber and silent, per the comp

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                    from: fireAt)
        center.add(UNNotificationRequest(
            identifier: id, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    func cancelOverdueNudge(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.overdueId(id)])
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banners even while the app is in the foreground — except the silent
    /// ones, which should stay silent wherever they land (RA5, RA8).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        let category = notification.request.content.categoryIdentifier
        if category == TweliNotification.Category.completion
            || category == TweliNotification.Category.mood {
            return [.banner, .list]              // no .sound
        }
        return [.banner, .sound, .list]
    }

    /// Route a tapped action. The work itself belongs to the services, so this
    /// only translates an identifier into an intent and hands it on — a handler
    /// wired by AppViewModel, which is the only thing that can see them all.
    var onAction: ((NotificationActionIntent) -> Void)?

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let reminderId = (info["reminderId"] as? String).flatMap(UUID.init(uuidString:))
        let text = (response as? UNTextInputNotificationResponse)?.userText

        await MainActor.run {
            guard let intent = NotificationActionIntent(actionId: response.actionIdentifier,
                                                        reminderId: reminderId,
                                                        text: text) else { return }
            self.onAction?(intent)
        }
    }
}

/// What a tapped notification action means, independent of UserNotifications.
enum NotificationActionIntent {
    case markReminderDone(UUID)
    case snoozeReminder(UUID)
    case replyToPartner(String)
    case openLetters
    case saveLetterForTonight
    case sendLoveBack
    case checkInOnPartner
    case acceptDate
    case suggestAnotherTime
    case openApp

    init?(actionId: String, reminderId: UUID?, text: String?) {
        switch actionId {
        case TweliNotification.Action.markDone:
            guard let reminderId else { return nil }
            self = .markReminderDone(reminderId)
        case TweliNotification.Action.snooze:
            guard let reminderId else { return nil }
            self = .snoozeReminder(reminderId)
        case TweliNotification.Action.replyToPartner:
            guard let text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            self = .replyToPartner(text)
        case TweliNotification.Action.openLetter:        self = .openLetters
        case TweliNotification.Action.saveLetterForTonight: self = .saveLetterForTonight
        case TweliNotification.Action.sendLoveBack:      self = .sendLoveBack
        case TweliNotification.Action.checkIn:           self = .checkInOnPartner
        case TweliNotification.Action.dateAccept:        self = .acceptDate
        case TweliNotification.Action.dateSuggestAnother: self = .suggestAnotherTime
        case UNNotificationDefaultActionIdentifier:      self = .openApp
        default: return nil                              // dismiss, or unknown
        }
    }
}

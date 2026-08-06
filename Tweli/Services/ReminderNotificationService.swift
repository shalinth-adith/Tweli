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
        content.title = reminder.title
        switch reminder.assignedTo {
        case .both:
            // Fires on both phones; only the person who didn't set it needs
            // telling who did.
            content.subtitle = mine ? "For both of you 💞" : "\(who) set this for both of you 💞"
        case .partner:
            // Only ever delivered to the partner — so the reader IS the person
            // it was set for. Saying "a nudge for your partner" here told them
            // it was meant for someone else.
            content.subtitle = "\(who) asked you to remember this 💗"
        case .me:
            // Only ever delivered to the person who set it; no attribution needed.
            break
        }
        content.body = reminder.note.isEmpty
            ? "A small care reminder ❤️"
            : reminder.note
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

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banners even while the app is in the foreground.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

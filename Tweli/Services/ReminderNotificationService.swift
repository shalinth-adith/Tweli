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

    func schedule(for reminder: ReminderItem) {
        guard !reminder.isCompleted else { return }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.note.isEmpty
            ? "A small care reminder from your partner ❤️"
            : reminder.note
        content.sound = .default

        let cal = Calendar.current
        let d = reminder.reminderDate
        let comps: DateComponents
        switch reminder.repeatType {
        case .none, .custom:
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

    func reschedule(for reminder: ReminderItem) {
        cancel(id: reminder.id)
        schedule(for: reminder)
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

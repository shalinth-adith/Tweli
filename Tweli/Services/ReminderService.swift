//
//  ReminderService.swift
//  Tweli
//
//  Owns reminder data + business logic. Mock-first (seeded from MockData);
//  every mutation also (a) schedules/cancels the local notification, (b) calls
//  the CloudKit placeholder, and (c) fires `onDataChanged` so the widget refreshes.
//

import Foundation
import Combine

@MainActor
final class ReminderService: ObservableObject {

    @Published private(set) var reminders: [ReminderItem]

    /// Set by AppViewModel — used to stamp `completedBy` on the current device.
    var currentUserId = UUID()
    /// AppViewModel hooks this to refresh the widget snapshot after any change.
    var onDataChanged: (() -> Void)?

    private let notifications: ReminderNotificationService
    private let cloud: FirebaseService

    init(notifications: ReminderNotificationService, cloud: FirebaseService) {
        self.notifications = notifications
        self.cloud = cloud
        self.reminders = []
#if DEBUG
        if AppEnvironment.useDemoData { self.reminders = MockData.reminders }
#endif
    }

    /// Schedule local notifications for all current reminders. Called once at
    /// startup (NOT from init — init must stay side-effect free, see AppViewModel).
    func scheduleAll() {
        for r in reminders { applySchedule(r) }
    }

    // MARK: - Notification routing (timezone- & assignment-aware)

    /// Fire (or cancel) the local notification for a reminder on THIS device.
    /// A completed reminder — or one this device isn't the actor for — is cancelled,
    /// so re-running is idempotent and assignment/timezone changes self-correct.
    private func applySchedule(_ r: ReminderItem) {
        if !r.isCompleted && shouldRing(r) {
            notifications.reschedule(for: r)   // cancel + schedule
        } else {
            notifications.cancel(id: r.id)
        }
    }

    /// Whether THIS device should ring for a reminder, based on who it's for:
    /// `.me` rings only on the creator's device, `.partner` only on the other's,
    /// `.both` on both. Combined with the wall-clock scheduling in
    /// `ReminderNotificationService`, a partner-assigned "9:30 AM" fires at 9:30 AM
    /// in the partner's own timezone — not the setter's.
    private func shouldRing(_ r: ReminderItem) -> Bool {
        switch r.assignedTo {
        case .both:    return true
        case .me:      return r.createdBy == currentUserId
        case .partner: return r.createdBy != currentUserId
        }
    }

    // MARK: - CRUD

    func add(_ reminder: ReminderItem) {
        reminders.append(reminder)
        applySchedule(reminder)
        Task { await cloud.saveReminder(reminder) }
        onDataChanged?()
    }

    func update(_ reminder: ReminderItem) {
        guard let i = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        var updated = reminder
        updated.updatedAt = Date()
        reminders[i] = updated
        applySchedule(updated)
        Task { await cloud.saveReminder(updated) }
        onDataChanged?()
    }

    func delete(_ reminder: ReminderItem) {
        reminders.removeAll { $0.id == reminder.id }
        notifications.cancel(id: reminder.id)
        Task { await cloud.deleteReminder(reminder) }
        onDataChanged?()
    }

    // MARK: - Actions

    func toggleDone(_ reminder: ReminderItem) {
        guard let i = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        var r = reminders[i]
        r.isCompleted.toggle()
        if r.isCompleted {
            r.status = .completed
            r.completedBy = currentUserId
            r.completedAt = Date()
        } else {
            r.status = .pending
            r.completedBy = nil
            r.completedAt = nil
        }
        r.updatedAt = Date()
        reminders[i] = r
        applySchedule(r)   // cancels when completed, re-rings when un-completed
        onDataChanged?()
    }

    func snooze(_ reminder: ReminderItem, minutes: Int = 10) {
        guard let i = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        var r = reminders[i]
        r.reminderDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        // Snooze is an absolute "in N minutes" on THIS device — re-anchor the
        // wall clock here so localFireDate doesn't re-shift it across zones.
        r.authorTimezone = TimeZone.current.identifier
        r.status = .snoozed
        r.updatedAt = Date()
        reminders[i] = r
        applySchedule(r)
        onDataChanged?()
    }

    func reschedule(_ reminder: ReminderItem, to newDate: Date) {
        guard let i = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        var r = reminders[i]
        r.reminderDate = newDate
        // The new time is a wall-clock chosen on THIS device — anchor it here.
        r.authorTimezone = TimeZone.current.identifier
        r.status = .pending
        r.updatedAt = Date()
        reminders[i] = r
        applySchedule(r)
        onDataChanged?()
    }

    /// "Send a gentle nudge later" — a one-off soft ping in `minutes`.
    func sendGentleNudge(_ reminder: ReminderItem, minutes: Int = 30) {
        notifications.scheduleOneOff(
            id: "nudge-\(reminder.id.uuidString)",
            title: "A gentle nudge 💗",
            body: "Don't forget: \(reminder.title)",
            at: Date().addingTimeInterval(TimeInterval(minutes * 60))
        )
    }

    // MARK: - Filters (design tabs: Today / Upcoming / Repeating / Completed / Missed)

    var today: [ReminderItem] { reminders.filter { $0.isToday }.sorted { $0.reminderDate < $1.reminderDate } }
    var upcoming: [ReminderItem] { reminders.filter { $0.isUpcoming }.sorted { $0.reminderDate < $1.reminderDate } }
    var missed: [ReminderItem] { reminders.filter { $0.isMissed }.sorted { $0.reminderDate > $1.reminderDate } }
    var completed: [ReminderItem] { reminders.filter { $0.isCompleted }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) } }
    var repeating: [ReminderItem] { reminders.filter { $0.isRepeating }.sorted { $0.reminderDate < $1.reminderDate } }

    /// The soonest pending reminder — shown on the Home dashboard.
    var nextReminder: ReminderItem? {
        reminders.filter { !$0.isCompleted && $0.reminderDate >= Date() }
            .min { $0.reminderDate < $1.reminderDate }
    }

    /// Merge records that arrived from CloudKit (upsert by id, then apply deletes).
    func mergeRemote(_ items: [ReminderItem], deletedIDs: [UUID]) {
        for item in items {
            if let i = reminders.firstIndex(where: { $0.id == item.id }) { reminders[i] = item }
            else { reminders.append(item) }
            // A remote reminder must ring on THIS device too — but only if this
            // device is the intended actor (applySchedule enforces assignment),
            // and it fires at the reminder's wall clock in THIS device's zone.
            // Without this, partner-created reminders only got scheduled on the
            // next app launch (bootstrapNotifications).
            applySchedule(item)
        }
        for id in deletedIDs where reminders.contains(where: { $0.id == id }) {
            notifications.cancel(id: id)
        }
        if !deletedIDs.isEmpty { reminders.removeAll { deletedIDs.contains($0.id) } }
    }

    /// Today's completion progress (0…1) for the Home "today progress" ring.
    var todayProgress: Double {
        let items = today
        guard !items.isEmpty else { return 0 }
        return Double(items.filter { $0.isCompleted }.count) / Double(items.count)
    }
}

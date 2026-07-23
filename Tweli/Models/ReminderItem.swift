//
//  ReminderItem.swift
//  Tweli
//

import Foundation

/// A shared care reminder. Every reminder can carry a `note` (the "love note").
struct ReminderItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var note: String = ""
    var createdBy: UUID
    var assignedTo: ReminderAssignee = .both
    var coupleSpaceId: UUID
    var reminderDate: Date
    var repeatType: RepeatType = .none
    var visibility: ReminderVisibility = .shared
    var priority: ReminderPriority = .normal
    var status: ReminderStatus = .pending
    var isCompleted: Bool = false
    var completedBy: UUID? = nil
    var completedAt: Date? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// IANA timezone of the device that created this reminder (e.g. "Asia/Kolkata").
    /// Lets `9:30 AM` mean a WALL-CLOCK time: across timezones the partner sees —
    /// and is notified at — 9:30 AM their local time, not the shifted instant.
    /// nil on legacy reminders → falls back to the absolute instant (old behavior).
    var authorTimezone: String? = nil

    // MARK: - Timezone-aware wall clock

    /// The reminder's wall-clock time re-expressed as an instant in the CURRENT
    /// device's local zone. Same-timezone couples: this equals `reminderDate`.
    /// Across timezones: it shifts the instant so the author's chosen wall clock
    /// ("9:30 AM") reads the same for the partner — which is also when the local
    /// notification fires on the actor's device.
    var localFireDate: Date {
        guard let tzId = authorTimezone,
              let authorTZ = TimeZone(identifier: tzId),
              authorTZ.identifier != TimeZone.current.identifier else { return reminderDate }
        var authorCal = Calendar.current
        authorCal.timeZone = authorTZ
        let comps = authorCal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: reminderDate)
        return Calendar.current.date(from: comps) ?? reminderDate
    }

    // MARK: - Computed helpers (used by the list filters & rows)

    var isToday: Bool { Calendar.current.isDateInToday(localFireDate) }

    var isUpcoming: Bool {
        !isCompleted && localFireDate > Date() && !isToday
    }

    var isMissed: Bool {
        !isCompleted && localFireDate < Date() && !isToday
    }

    var isRepeating: Bool { repeatType != .none }

    /// Short time label like "9:30 PM" shown on the row (recipient's local wall clock).
    var timeLabel: String {
        localFireDate.formatted(date: .omitted, time: .shortened)
    }
}

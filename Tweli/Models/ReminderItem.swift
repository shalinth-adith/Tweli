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

    // MARK: - Computed helpers (used by the list filters & rows)

    var isToday: Bool { Calendar.current.isDateInToday(reminderDate) }

    var isUpcoming: Bool {
        !isCompleted && reminderDate > Date() && !isToday
    }

    var isMissed: Bool {
        !isCompleted && reminderDate < Date() && !isToday
    }

    var isRepeating: Bool { repeatType != .none }

    /// Short time label like "9:30 PM" shown on the row.
    var timeLabel: String {
        reminderDate.formatted(date: .omitted, time: .shortened)
    }
}

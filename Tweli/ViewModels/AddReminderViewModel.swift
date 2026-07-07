//
//  AddReminderViewModel.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class AddReminderViewModel: ObservableObject {
    @Published var title = ""
    @Published var note = ""
    @Published var assignedTo: ReminderAssignee = .both
    @Published var date = Date()
    @Published var time = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var repeatType: RepeatType = .none
    @Published var visibility: ReminderVisibility = .shared
    @Published var priority: ReminderPriority = .normal

    var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    private var combinedDate: Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day; c.hour = t.hour; c.minute = t.minute
        return cal.date(from: c) ?? date
    }

    func build(createdBy: UUID, coupleSpaceId: UUID) -> ReminderItem {
        ReminderItem(title: title.trimmingCharacters(in: .whitespaces),
                     note: note,
                     createdBy: createdBy,
                     assignedTo: assignedTo,
                     coupleSpaceId: coupleSpaceId,
                     reminderDate: combinedDate,
                     repeatType: repeatType,
                     visibility: visibility,
                     priority: priority)
    }
}

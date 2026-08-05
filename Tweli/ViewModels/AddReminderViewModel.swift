//
//  AddReminderViewModel.swift
//  Tweli
//
//  State + validation for the New Reminder sheet (comp R1–R4).
//
//  Validation follows R2's rule: errors are inline, kind and specific. They are
//  raised only after a save attempt — a sheet that scolds you while you are
//  still typing the first character is the thing R1 is trying not to be.
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

    /// Set once the user has tried to save. Until then the sheet stays quiet.
    @Published private(set) var didAttemptSave = false

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Comp R1: "Save stays quiet until the sheet earns it."
    var canSave: Bool { !trimmedTitle.isEmpty }

    // MARK: - Validation (comp R2)

    /// "Give it a name — even just "call her"."
    var titleError: String? {
        guard didAttemptSave, trimmedTitle.isEmpty else { return nil }
        return "Give it a name — even just “call her”."
    }

    /// "1:00 AM already passed today — pick a later time, or tomorrow."
    /// Only applies to one-off reminders; a repeating one legitimately points at
    /// a wall clock that has already gone by today.
    var timeError: String? {
        guard didAttemptSave, repeatType == .none, combinedDate < Date() else { return nil }
        let clock = combinedDate.formatted(date: .omitted, time: .shortened)
        let sameDay = Calendar.current.isDateInToday(combinedDate)
        return sameDay
            ? "\(clock) already passed today — pick a later time, or tomorrow."
            : "That moment has already passed — pick a date ahead of now."
    }

    var hasErrors: Bool { titleError != nil || timeError != nil }

    /// Runs validation and reports whether the reminder is safe to save.
    func validate() -> Bool {
        didAttemptSave = true
        return !hasErrors
    }

    /// Clears the error state when the user edits — errors reappear on the next
    /// save attempt, not mid-keystroke.
    func clearAttempt() { didAttemptSave = false }

    // MARK: - Derived

    var combinedDate: Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day; c.hour = t.hour; c.minute = t.minute
        return cal.date(from: c) ?? date
    }

    /// Comp R1: "9:00 PM your time lands as her 7:00 AM in Abu Dhabi."
    ///
    /// Only produced when we actually know the partner's zone AND it differs
    /// from ours — otherwise there is no second clock to report and the line is
    /// omitted rather than stating something obvious or invented.
    func timezoneHint(partnerName: String, partnerTimeZoneId: String?, partnerCity: String?) -> String? {
        guard assignedTo != .me,
              let id = partnerTimeZoneId,
              let zone = TimeZone(identifier: id),
              zone.identifier != TimeZone.current.identifier else { return nil }

        let mine = combinedDate.formatted(date: .omitted, time: .shortened)
        var fmt = Date.FormatStyle.dateTime.hour().minute()
        fmt.timeZone = zone
        let theirs = combinedDate.formatted(fmt)

        let city = partnerCity?.split(separator: ",").first.map(String.init)
        let place = city.map { " in \($0)" } ?? ""
        let who = partnerName.isEmpty ? "your partner" : partnerName
        return "\(mine) your time lands as \(who)'s \(theirs)\(place)."
    }

    func build(createdBy: UUID, coupleSpaceId: UUID) -> ReminderItem {
        ReminderItem(title: trimmedTitle,
                     note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                     createdBy: createdBy,
                     assignedTo: assignedTo,
                     coupleSpaceId: coupleSpaceId,
                     reminderDate: combinedDate,
                     repeatType: repeatType,
                     visibility: visibility,
                     priority: priority,
                     authorTimezone: TimeZone.current.identifier)
    }
}

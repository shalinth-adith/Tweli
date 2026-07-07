//
//  VirtualDateItem.swift
//  Tweli
//

import Foundation

/// A planned long-distance date ("Movie night at 9:30 PM").
struct VirtualDateItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var date: Date
    var notes: String = ""
    var coupleSpaceId: UUID
    var createdBy: UUID
    var status: VirtualDateStatus = .planned
    var reminderEnabled: Bool = true
    var createdAt: Date = Date()

    /// Label like "Tonight · 9:30 PM" / "Sat · 8:00 PM" for cards.
    var whenLabel: String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) { return "Tonight · \(time)" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow · \(time)" }
        let day = date.formatted(.dateTime.weekday(.abbreviated))
        return "\(day) · \(time)"
    }
}

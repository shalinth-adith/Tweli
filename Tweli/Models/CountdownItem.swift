//
//  CountdownItem.swift
//  Tweli
//

import Foundation

/// A shared moment to look forward to ("21 days until we meet again").
struct CountdownItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var targetDate: Date
    var note: String = ""
    var category: CountdownCategory = .custom
    var isPinned: Bool = false
    var createdBy: UUID
    var coupleSpaceId: UUID
    var createdAt: Date = Date()

    /// Whole days from now until the target (clamped at 0).
    var daysRemaining: Int {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: targetDate)
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return max(0, days)
    }

    /// Progress 0…1 assuming a 90-day horizon — drives the hero progress bar / ring.
    var progress: Double {
        let horizon = 90.0
        return min(1, max(0, (horizon - Double(daysRemaining)) / horizon))
    }

    /// Warm notification body delivered on the day the countdown reaches zero.
    var arrivalMessage: String {
        switch category {
        case .meeting: return "The day is finally here — you meet today! 💞"
        case .birthday: return "It's the big day — happy birthday! 🎂"
        case .anniversary: return "Happy anniversary! 💕"
        case .trip: return "Trip day is here — time to go! ✈️"
        case .call: return "It's time — your call is today 💗"
        case .distanceEnds: return "The distance ends today. 🥹"
        case .custom: return "Today's the day you've been counting down to 💕"
        }
    }
}

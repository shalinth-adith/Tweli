//
//  Enums.swift
//  Tweli
//
//  All shared enums for the domain model. Each carries a display `label`
//  and, where the UI needs it, an SF Symbol name and a tint color.
//

import SwiftUI

// MARK: - Reminder assignment

enum ReminderAssignee: String, Codable, CaseIterable, Identifiable {
    case me, partner, both
    var id: String { rawValue }

    var label: String {
        switch self {
        case .me: return "Me"
        case .partner: return "Partner"
        case .both: return "Both"
        }
    }

    var sfSymbol: String {
        switch self {
        case .me: return "person.fill"
        case .partner: return "heart.fill"
        case .both: return "person.2.fill"
        }
    }
}

// MARK: - Repeat

enum RepeatType: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, monthly, custom
    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }

    var sfSymbol: String { self == .none ? "" : "repeat" }
}

// MARK: - Visibility

enum ReminderVisibility: String, Codable, CaseIterable, Identifiable {
    case shared
    case privateOnly
    case secretUntilDate
    var id: String { rawValue }

    var label: String {
        switch self {
        case .shared: return "Shared"
        case .privateOnly: return "Private"
        case .secretUntilDate: return "Secret until date"
        }
    }

    var sfSymbol: String {
        switch self {
        case .shared: return "person.2"
        case .privateOnly: return "lock"
        case .secretUntilDate: return "clock.badge.questionmark"
        }
    }
}

// MARK: - Priority

enum ReminderPriority: String, Codable, CaseIterable, Identifiable {
    case low, normal, important
    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .important: return "Important"
        }
    }

    var tint: Color {
        switch self {
        case .low: return .twInkTertiary
        case .normal: return .twAccent2
        case .important: return .twWarn
        }
    }
}

// MARK: - Status

enum ReminderStatus: String, Codable, CaseIterable, Identifiable {
    case pending, completed, missed, snoozed
    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .missed: return "Missed"
        case .snoozed: return "Snoozed"
        }
    }

    var tint: Color {
        switch self {
        case .pending: return .twInkSecondary
        case .completed: return .twSuccess
        case .missed: return .twWarn
        case .snoozed: return .twAccent2
        }
    }
}

// MARK: - Countdown category

enum CountdownCategory: String, Codable, CaseIterable, Identifiable {
    case meeting, birthday, anniversary, trip, call, distanceEnds, custom
    var id: String { rawValue }

    var label: String {
        switch self {
        case .meeting: return "Meeting"
        case .birthday: return "Birthday"
        case .anniversary: return "Anniversary"
        case .trip: return "Trip"
        case .call: return "Call"
        case .distanceEnds: return "Distance ends"
        case .custom: return "Custom"
        }
    }

    var sfSymbol: String {
        switch self {
        case .meeting: return "figure.2"
        case .birthday: return "gift.fill"
        case .anniversary: return "heart.circle.fill"
        case .trip: return "airplane"
        case .call: return "video.fill"
        case .distanceEnds: return "location.fill"
        case .custom: return "star.fill"
        }
    }
}

// MARK: - Virtual date status

enum VirtualDateStatus: String, Codable, CaseIterable, Identifiable {
    case planned, completed, cancelled
    var id: String { rawValue }

    var label: String {
        switch self {
        case .planned: return "Planned"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var tint: Color {
        switch self {
        case .planned: return .twAccent2
        case .completed: return .twSuccess
        case .cancelled: return .twInkTertiary
        }
    }
}

// MARK: - Partner mood

enum PartnerMood: String, Codable, CaseIterable, Identifiable {
    case missingYou, busyToday, lowEnergy, needReassurance
    case needCall, needSpace, excitedToMeet, traveling
    var id: String { rawValue }

    var label: String {
        switch self {
        case .missingYou: return "Missing you"
        case .busyToday: return "Busy today"
        case .lowEnergy: return "Low energy"
        case .needReassurance: return "Need reassurance"
        case .needCall: return "Need a call"
        case .needSpace: return "Need space"
        case .excitedToMeet: return "Excited to meet"
        case .traveling: return "Traveling"
        }
    }

    var emoji: String {
        switch self {
        case .missingYou: return "🥺"
        case .busyToday: return "💼"
        case .lowEnergy: return "🌙"
        case .needReassurance: return "🫂"
        case .needCall: return "📞"
        case .needSpace: return "🌿"
        case .excitedToMeet: return "✨"
        case .traveling: return "✈️"
        }
    }

    var sfSymbol: String {
        switch self {
        case .missingYou: return "heart.fill"
        case .busyToday: return "briefcase.fill"
        case .lowEnergy: return "moon.fill"
        case .needReassurance: return "hands.and.sparkles.fill"
        case .needCall: return "phone.fill"
        case .needSpace: return "leaf.fill"
        case .excitedToMeet: return "sparkles"
        case .traveling: return "airplane"
        }
    }
}

//
//  MockData.swift
//  Tweli
//
//  Single source of seeded sample data used by every service (mock-first)
//  and by SwiftUI previews. Replaced by CloudKit-backed data in Phase 5.
//

import Foundation

enum MockData {

    // MARK: - Stable identities (so references line up across models)

    static let shalinthId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let anayaId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let spaceId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    static let shalinth = UserProfile(id: shalinthId, displayName: "Shalinth", avatarEmoji: "🧑🏻")
    static let anaya = UserProfile(id: anayaId, displayName: "Anaya", avatarEmoji: "👩🏻")

    static let coupleSpace = CoupleSpace(
        id: spaceId,
        title: "Shalinth & Anaya",
        createdBy: shalinthId,
        partnerIds: [shalinthId, anayaId]
    )

    // MARK: - Date helpers

    private static func today(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private static func daysFromNow(_ days: Int, hour: Int = 20, minute: Int = 0) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }

    // MARK: - Reminders

    static var reminders: [ReminderItem] {
        [
            ReminderItem(title: "Take omega-3 tablet", note: "Don't skip this, I want you healthy ❤️",
                         createdBy: anayaId, assignedTo: .me, coupleSpaceId: spaceId,
                         reminderDate: today(9, 0), repeatType: .daily, priority: .important,
                         status: .completed, isCompleted: true, completedBy: shalinthId, completedAt: today(9, 5)),
            ReminderItem(title: "Call each other", note: "Same time as always 🥰",
                         createdBy: shalinthId, assignedTo: .both, coupleSpaceId: spaceId,
                         reminderDate: today(21, 30), repeatType: .daily),
            ReminderItem(title: "Drink water", note: "Stay hydrated love",
                         createdBy: anayaId, assignedTo: .both, coupleSpaceId: spaceId,
                         reminderDate: today(15, 0), repeatType: .daily, priority: .low),
            ReminderItem(title: "Send good night message", note: "",
                         createdBy: shalinthId, assignedTo: .me, coupleSpaceId: spaceId,
                         reminderDate: today(23, 0), repeatType: .daily),
            ReminderItem(title: "Book tickets for next trip", note: "Before prices go up!",
                         createdBy: shalinthId, assignedTo: .both, coupleSpaceId: spaceId,
                         reminderDate: daysFromNow(3, hour: 19), priority: .important),
            ReminderItem(title: "Write open-when letter", note: "One for when she can't sleep",
                         createdBy: shalinthId, assignedTo: .me, coupleSpaceId: spaceId,
                         reminderDate: daysFromNow(1, hour: 22)),
            ReminderItem(title: "Send good morning message", note: "",
                         createdBy: anayaId, assignedTo: .partner, coupleSpaceId: spaceId,
                         reminderDate: today(8, 0), repeatType: .daily, status: .missed)
        ]
    }

    // MARK: - Countdowns

    static var countdowns: [CountdownItem] {
        [
            CountdownItem(title: "Until we meet again", targetDate: daysFromNow(21, hour: 10),
                          note: "Closer every day ❤️", category: .meeting, isPinned: true,
                          createdBy: shalinthId, coupleSpaceId: spaceId),
            CountdownItem(title: "Her birthday", targetDate: daysFromNow(12, hour: 0),
                          category: .birthday, createdBy: shalinthId, coupleSpaceId: spaceId),
            CountdownItem(title: "Our anniversary", targetDate: daysFromNow(37, hour: 0),
                          category: .anniversary, createdBy: anayaId, coupleSpaceId: spaceId),
            CountdownItem(title: "Distance ends", targetDate: daysFromNow(143, hour: 0),
                          note: "The last stretch", category: .distanceEnds,
                          createdBy: shalinthId, coupleSpaceId: spaceId)
        ]
    }

    // MARK: - Virtual dates

    static var virtualDates: [VirtualDateItem] {
        [
            VirtualDateItem(title: "Movie night", date: today(21, 30),
                            notes: "You pick the film this time 🍿", coupleSpaceId: spaceId, createdBy: shalinthId),
            VirtualDateItem(title: "Coffee call", date: daysFromNow(1, hour: 9),
                            notes: "Morning coffee together", coupleSpaceId: spaceId, createdBy: anayaId),
            VirtualDateItem(title: "Study together", date: daysFromNow(2, hour: 16),
                            coupleSpaceId: spaceId, createdBy: shalinthId),
            VirtualDateItem(title: "Playlist night", date: daysFromNow(4, hour: 22),
                            notes: "Share 5 songs each", coupleSpaceId: spaceId, createdBy: anayaId),
            VirtualDateItem(title: "Dinner over video call", date: daysFromNow(6, hour: 20),
                            coupleSpaceId: spaceId, createdBy: shalinthId)
        ]
    }

    // MARK: - Open-when letters

    static var letters: [OpenWhenLetter] {
        [
            OpenWhenLetter(title: "Open when you miss me",
                           message: "Close your eyes. I'm holding your hand across all these miles. Only \(21) sleeps to go. — S",
                           createdBy: shalinthId, coupleSpaceId: spaceId),
            OpenWhenLetter(title: "Open when you feel low",
                           message: "You are the strongest, softest person I know. This feeling will pass, and I'll be right here when it does.",
                           createdBy: shalinthId, coupleSpaceId: spaceId, isOpened: true, openedAt: Date().addingTimeInterval(-86400)),
            OpenWhenLetter(title: "Open when you can't sleep",
                           message: "Count our someday-mornings instead of sheep. Coffee, your messy hair, no goodbyes.",
                           createdBy: anayaId, coupleSpaceId: spaceId),
            OpenWhenLetter(title: "Open when we fight",
                           message: "I already forgive you. We're on the same team, always.",
                           createdBy: anayaId, coupleSpaceId: spaceId),
            OpenWhenLetter(title: "Open when you need motivation",
                           message: "Every day you push through brings us one day closer. I'm so proud of you.",
                           createdBy: shalinthId, coupleSpaceId: spaceId, unlockDate: Date().addingTimeInterval(86400 * 3))
        ]
    }

    // MARK: - Moods

    static var moods: [MoodStatus] {
        [
            MoodStatus(userId: anayaId, mood: .missingYou, note: nil, updatedAt: Date().addingTimeInterval(-7200)),
            MoodStatus(userId: shalinthId, mood: .excitedToMeet, note: nil, updatedAt: Date().addingTimeInterval(-3600))
        ]
    }

    /// Partner's mood over the last 7 days (oldest → newest) for the Moods history bar.
    static var partnerWeekMoods: [PartnerMood] {
        [.missingYou, .missingYou, .excitedToMeet, .lowEnergy, .missingYou, .needReassurance, .missingYou]
    }

    // MARK: - Pings

    static var pings: [MissingYouPing] {
        [
            MissingYouPing(message: "Anaya misses you ❤️", sentBy: anayaId, sentTo: shalinthId,
                           coupleSpaceId: spaceId, sentAt: Date().addingTimeInterval(-1800)),
            MissingYouPing(message: "A small hug from far away 🫂", sentBy: shalinthId, sentTo: anayaId,
                           coupleSpaceId: spaceId, sentAt: Date().addingTimeInterval(-9000))
        ]
    }
}

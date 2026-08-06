//
//  NotificationPreferences.swift
//  Tweli
//
//  Comp V3 — "Notification settings: per-type switches, and quiet hours for
//  both of you".
//
//  These live on the SPACE document under `notificationPrefs[uid]`, not in
//  UserDefaults, because the push function has to read them before it sends.
//  A switch that only existed on the device would silence the banner but the
//  push would still arrive — which is worse than no switch at all.
//
//  The quiet window replaces the constants that used to be hard-coded in
//  functions/index.js. Defaults match what those constants were, so anyone who
//  never opens this screen keeps exactly the behaviour they had.
//

import Foundation

struct NotificationPreferences: Codable, Equatable {
    // From your partner
    var moods = true
    var letters = true
    /// "Her morning" — a nudge when your partner's day starts.
    var partnerMorning = false

    // From Tweli itself
    var reminders = true
    var countdownMilestones = true

    // Quiet hours, in the OWNER's local hours (0–23). `start > end` is normal
    // and means the window crosses midnight, e.g. 22 → 8.
    var quietStart = 22
    var quietEnd = 8

    static let `default` = NotificationPreferences()

    /// True when `hour` falls inside the quiet window, handling the wrap.
    func isQuiet(hour: Int) -> Bool {
        guard quietStart != quietEnd else { return false }   // empty window
        return quietStart > quietEnd
            ? (hour >= quietStart || hour < quietEnd)        // crosses midnight
            : (hour >= quietStart && hour < quietEnd)
    }

    /// The shape written to Firestore. Kept as a flat [String: Any] so the
    /// Cloud Function can read it without a schema, and so a field added later
    /// by one client doesn't break an older one.
    var firestoreValue: [String: Any] {
        [
            "moods": moods,
            "letters": letters,
            "partnerMorning": partnerMorning,
            "reminders": reminders,
            "countdownMilestones": countdownMilestones,
            "quietStart": quietStart,
            "quietEnd": quietEnd,
        ]
    }

    init() {}

    /// Rebuilds from the Firestore map, falling back to the default for any key
    /// an older client never wrote.
    init(firestore: [String: Any]) {
        moods = firestore["moods"] as? Bool ?? true
        letters = firestore["letters"] as? Bool ?? true
        partnerMorning = firestore["partnerMorning"] as? Bool ?? false
        reminders = firestore["reminders"] as? Bool ?? true
        countdownMilestones = firestore["countdownMilestones"] as? Bool ?? true
        quietStart = firestore["quietStart"] as? Int ?? 22
        quietEnd = firestore["quietEnd"] as? Int ?? 8
    }
}

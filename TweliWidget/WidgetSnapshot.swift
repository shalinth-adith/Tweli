//
//  WidgetSnapshot.swift  (widget target copy)
//  TweliWidget
//
//  IDENTICAL contract to the app's `Tweli/Services/WidgetDataService.swift`
//  `WidgetSnapshot` — keep the fields in sync. The app writes this JSON into the
//  App Group; the widget reads it here.
//

import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var daysUntil: Int
    var countdownTitle: String
    var partnerName: String
    var partnerMood: String
    var partnerMoodEmoji: String
    var nextDateTitle: String
    var nextDateTime: String
    // Partner's mood note — the custom message that sits on the "Two of us" widget.
    var partnerMoodNote: String = ""
    // Reunion progress 0…1 for the widget's S———A thread (heart position).
    var countdownProgress: Double = 0
    var userInitial: String = "You"   // left dot on the "Two of us" thread
    // Latest missing-you ping (reflects a "send love" tap in the widget).
    var lastPingMessage: String = "Send a little love"
    var lastPingFrom: String = "—"
    var lastPingWhen: String = ""

    static let placeholder = WidgetSnapshot(
        daysUntil: 21,
        countdownTitle: "Until we meet again",
        partnerName: "Your partner",
        partnerMood: "Missing you",
        partnerMoodEmoji: "🥺",
        nextDateTitle: "Your next date",
        nextDateTime: "9:30 PM",
        partnerMoodNote: "Wish you were here right now",
        countdownProgress: 0.64,
        lastPingMessage: "Missing you ❤️",
        lastPingFrom: "Your partner",
        lastPingWhen: "2h ago"
    )

    static let appGroupId = "group.me.adithyan.shalinth.Tweli"
    static let snapshotKey = "tweli.widget.snapshot"

    /// Reads the latest snapshot from the App Group, or the placeholder if unavailable.
    static func load() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: appGroupId)?.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .placeholder }
        return snapshot
    }
}

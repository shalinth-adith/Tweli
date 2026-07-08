//
//  WidgetDataService.swift
//  Tweli
//
//  Writes a small snapshot of "at a glance" data to the App Group so the
//  WidgetKit extension can render it. App writes → widget reads.
//

import Foundation
import Combine
import WidgetKit

/// The serialization contract shared with the widget target via the App Group.
/// NOTE: `TweliWidget/WidgetSnapshot.swift` holds an IDENTICAL copy — keep in sync.
struct WidgetSnapshot: Codable, Equatable {
    var daysUntil: Int
    var countdownTitle: String
    var partnerName: String
    var partnerMood: String
    var partnerMoodEmoji: String
    var nextDateTitle: String
    var nextDateTime: String
    // Latest missing-you ping (reflects a "send love" tap in the widget).
    var lastPingMessage: String = "Send a little love"
    var lastPingFrom: String = "—"        // "You" or the partner's name
    var lastPingWhen: String = ""         // relative label, e.g. "now"

    static let placeholder = WidgetSnapshot(
        daysUntil: 21,
        countdownTitle: "Until we meet again",
        partnerName: "Anaya",
        partnerMood: "Missing you",
        partnerMoodEmoji: "🥺",
        nextDateTitle: "Movie night",
        nextDateTime: "9:30 PM",
        lastPingMessage: "Anaya misses you ❤️",
        lastPingFrom: "Anaya",
        lastPingWhen: "2h ago"
    )
}

@MainActor
final class WidgetDataService: ObservableObject {

    /// Must match the App Group id configured on both the app and widget targets.
    static let appGroupId = "group.me.adithyan.shalinth.Tweli"
    static let snapshotKey = "tweli.widget.snapshot"

    /// Persists the snapshot to the shared container and reloads widget timelines.
    /// Safely no-ops until the App Group entitlement is configured (suite == nil).
    func update(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId) else {
            print("[WidgetDataService] App Group not configured yet — skipping snapshot write.")
            return
        }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.snapshotKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

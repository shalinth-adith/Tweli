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
    /// Whole days until the reunion — the pill on the medium widget's thread.
    var daysUntil: Int = 0
    /// Reunion progress 0…1 — where the heart sits on the S———A thread.
    var countdownProgress: Double = 0
    /// The right-hand dot and the "<name> feels" eyebrow.
    var partnerName: String = "Your partner"
    /// The mood in plain words. Empty ⇒ nothing shared yet; the widget says so.
    var partnerMood: String = ""
    /// The message quoted beneath the mood.
    var partnerMoodNote: String = ""
    /// Initials for the left dot on the thread.
    var userInitial: String = ""

    /// Shown in the widget gallery and before the App Group has any data. It
    /// invents nothing — no mood, no message, no day count — so the preview is
    /// the app's genuine empty state rather than a staged one.
    static let placeholder = WidgetSnapshot()

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

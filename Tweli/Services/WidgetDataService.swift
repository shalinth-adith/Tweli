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

    /// Removes the shared payload entirely — used on account deletion, so a
    /// deleted account's last mood doesn't keep sitting on the Home Screen.
    /// The widget then falls back to its own empty placeholder.
    func clear() {
        UserDefaults(suiteName: Self.appGroupId)?.removeObject(forKey: Self.snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// How many Tweli widgets the user currently has placed.
    ///
    /// Comp K4 tells a returning user their widget is gone. That is true after
    /// almost every reinstall — but not after one where they re-added it before
    /// opening the app, and a screen that insists otherwise is describing a
    /// state that does not exist.
    ///
    /// Returns nil when WidgetKit could not answer (no App Group, an extension
    /// that failed to load, the simulator). Nil means UNKNOWN, and the caller
    /// must treat it as "don't claim anything" — reporting it as zero would
    /// turn a missing answer into a false one.
    func installedWidgetCount() async -> Int? {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                switch result {
                case .success(let widgets):
                    continuation.resume(returning: widgets.count)
                case .failure(let error):
                    print("[WidgetDataService] getCurrentConfigurations failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

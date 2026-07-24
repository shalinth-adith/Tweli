//
//  MoodStatus.swift
//  Tweli
//

import Foundation

/// A partner's current shared mood — reduces misunderstanding at a distance.
struct MoodStatus: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var userId: UUID
    var mood: PartnerMood
    /// A free-text mood the user typed instead of picking a preset (designs 24a/b).
    /// When non-empty it is what the partner sees; `mood` still backs the tint /
    /// SF Symbol on legacy surfaces (widget). nil/empty ⇒ a plain preset mood.
    var customText: String? = nil
    var note: String? = nil
    var updatedAt: Date = Date()

    /// What the partner actually reads: the typed mood if present, else the preset
    /// label. Every mood surface (home card, interstitial, strip) shows this.
    var displayLabel: String {
        if let t = customText?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        return mood.label
    }

    var relativeLabel: String {
        updatedAt.formatted(.relative(presentation: .named))
    }
}

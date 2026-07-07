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
    var note: String? = nil
    var updatedAt: Date = Date()

    var relativeLabel: String {
        updatedAt.formatted(.relative(presentation: .named))
    }
}

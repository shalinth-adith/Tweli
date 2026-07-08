//
//  MoodService.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class MoodService: ObservableObject {

    @Published private(set) var moods: [MoodStatus]

    var currentUserId: UUID = MockData.shalinthId
    var partnerId: UUID = MockData.anayaId
    var onDataChanged: (() -> Void)?
    private let cloud: CloudKitService

    init(cloud: CloudKitService) {
        self.cloud = cloud
        self.moods = MockData.moods
    }

    var myMood: MoodStatus? { moods.first { $0.userId == currentUserId } }
    var partnerMood: MoodStatus? { moods.first { $0.userId == partnerId } }

    /// Partner's mood across the last 7 days (oldest → newest) for the history bar.
    let partnerWeekMoods: [PartnerMood] = MockData.partnerWeekMoods

    func setMyMood(_ mood: PartnerMood, note: String? = nil) {
        if let i = moods.firstIndex(where: { $0.userId == currentUserId }) {
            moods[i].mood = mood
            moods[i].note = note
            moods[i].updatedAt = Date()
        } else {
            moods.append(MoodStatus(userId: currentUserId, mood: mood, note: note))
        }
        if let updated = myMood { Task { await cloud.saveMood(updated) } }
        onDataChanged?()
    }
}

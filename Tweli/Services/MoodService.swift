//
//  MoodService.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class MoodService: ObservableObject {

    @Published private(set) var moods: [MoodStatus]

    var currentUserId = UUID()   // set by AppViewModel.wireIdentities()
    var partnerId = UUID()
    var onDataChanged: (() -> Void)?
    private let cloud: FirebaseService

    init(cloud: FirebaseService) {
        self.cloud = cloud
#if DEBUG
        self.moods = MockData.moods   // demo data for design/dev builds only
#else
        self.moods = []
#endif
    }

    var myMood: MoodStatus? { moods.first { $0.userId == currentUserId } }
    var partnerMood: MoodStatus? { moods.first { $0.userId == partnerId } }

    /// Partner's mood across the last 7 days (oldest → newest) for the history bar.
#if DEBUG
    let partnerWeekMoods: [PartnerMood] = MockData.partnerWeekMoods
#else
    let partnerWeekMoods: [PartnerMood] = []
#endif

    /// Current user's mood across the last 7 days — today's slot updates when the
    /// user picks a new mood so their own meter reflects the change live.
#if DEBUG
    @Published private(set) var myWeekMoods: [PartnerMood] = MockData.myWeekMoods
#else
    @Published private(set) var myWeekMoods: [PartnerMood] = []
#endif

    func setMyMood(_ mood: PartnerMood, note: String? = nil) {
        if let i = moods.firstIndex(where: { $0.userId == currentUserId }) {
            moods[i].mood = mood
            moods[i].note = note
            moods[i].updatedAt = Date()
        } else {
            moods.append(MoodStatus(userId: currentUserId, mood: mood, note: note))
        }
        // Reflect today's mood in the user's own 7-day meter.
        if !myWeekMoods.isEmpty { myWeekMoods[myWeekMoods.count - 1] = mood }
        if let updated = myMood { Task { await cloud.saveMood(updated) } }
        onDataChanged?()
    }

    func mergeRemote(_ items: [MoodStatus], deletedIDs: [UUID]) {
        for item in items {
            if let i = moods.firstIndex(where: { $0.id == item.id }) { moods[i] = item }
            else { moods.append(item) }
        }
        if !deletedIDs.isEmpty { moods.removeAll { deletedIDs.contains($0.id) } }
    }
}

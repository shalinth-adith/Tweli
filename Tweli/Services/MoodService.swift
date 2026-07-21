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

    /// Persists the timestamp of the partner mood the user has already been
    /// greeted with, so the "new mood" interstitial shows once per fresh mood.
    private let defaults = UserDefaults.standard
    private let lastSeenPartnerMoodKey = "tweli.mood.lastSeenPartner"

    init(cloud: FirebaseService) {
        self.cloud = cloud
        self.moods = []
#if DEBUG
        if AppEnvironment.useDemoData {
            self.moods = MockData.moods
            self.myWeekMoods = MockData.myWeekMoods
        }
#endif
    }

    var myMood: MoodStatus? { moods.first { $0.userId == currentUserId } }
    var partnerMood: MoodStatus? { moods.first { $0.userId == partnerId } }

    /// The partner's mood only if they've *changed* it since we last recorded a
    /// baseline — this is what raises the "New mood" interstitial.
    ///
    /// The very first partner mood we ever observe is recorded silently as the
    /// baseline and returns nil: the card must not greet a first-time user (or
    /// the mood that was already there when they paired). Only a genuinely newer
    /// update afterwards returns non-nil.
    var freshPartnerMood: MoodStatus? {
        guard let mood = partnerMood else { return nil }
        guard let lastSeen = defaults.object(forKey: lastSeenPartnerMoodKey) as? Date else {
            // First partner mood ever seen → establish the baseline, don't greet.
            defaults.set(mood.updatedAt, forKey: lastSeenPartnerMoodKey)
            return nil
        }
        return mood.updatedAt > lastSeen ? mood : nil
    }

    /// Mark the current partner mood as seen. The strip stays on Home, but the
    /// interstitial won't raise again until a newer mood arrives.
    func acknowledgePartnerMood() {
        guard let mood = partnerMood else { return }
        defaults.set(mood.updatedAt, forKey: lastSeenPartnerMoodKey)
    }

    /// Partner's mood across the last 7 days (oldest → newest) for the history bar.
    /// Empty in production; demo data only when a developer opts in.
    var partnerWeekMoods: [PartnerMood] {
#if DEBUG
        return AppEnvironment.useDemoData ? MockData.partnerWeekMoods : []
#else
        return []
#endif
    }

    /// Current user's mood across the last 7 days — today's slot updates when the
    /// user picks a new mood so their own meter reflects the change live.
    @Published private(set) var myWeekMoods: [PartnerMood] = []

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

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
    /// Any mood NOT authored by me is the partner's (a space has exactly two
    /// people). Never match on `partnerId`: profile UUIDs live only on their own
    /// device, so the locally-fabricated partner id can't equal the real author id
    /// inside a synced payload. Newest wins if multiple (e.g. partner reinstalled).
    var partnerMood: MoodStatus? {
        moods.filter { $0.userId != currentUserId }.max { $0.updatedAt < $1.updatedAt }
    }

    /// The partner's mood if they've *changed* it since we last acknowledged one —
    /// this is what raises the "New mood" interstitial.
    ///
    /// The very FIRST partner mood we ever observe also counts as fresh: entering
    /// the session for the first time should greet the user with the mood their
    /// partner already set (design 21a/b), not swallow it as a silent baseline.
    /// Acknowledging (swipe/dismiss) records the baseline so it won't re-raise.
    var freshPartnerMood: MoodStatus? {
        guard let mood = partnerMood else { return nil }
        guard let lastSeen = defaults.object(forKey: lastSeenPartnerMoodKey) as? Date else {
            return mood   // first partner mood ever seen → greet on first entry
        }
        return mood.updatedAt > lastSeen ? mood : nil
    }

    /// True once the user has been greeted with (and acknowledged) any partner
    /// mood. False ⇒ the next partner mood to arrive is their first-entry greet.
    var hasGreetedPartnerMood: Bool {
        defaults.object(forKey: lastSeenPartnerMoodKey) != nil
    }

    /// Mark the current partner mood as seen. The strip stays on Home, but the
    /// interstitial won't raise again until a newer mood arrives.
    func acknowledgePartnerMood() {
        guard let mood = partnerMood else { return }
        defaults.set(mood.updatedAt, forKey: lastSeenPartnerMoodKey)
    }

    // MARK: - Keep vs Dismiss (interstitial swipe, designs 22a/b)

    private let collapsedMoodKey = "tweli.mood.collapsedToStrip"

    /// Right swipe = KEEP → the mood stays as the prominent card on Home.
    /// Left swipe = DISMISS → it collapses to the quiet strip. Keyed to the mood's
    /// timestamp so a NEWER partner mood starts fresh (card by default).
    func setPartnerMoodKept(_ kept: Bool) {
        guard let mood = partnerMood else { return }
        if kept {
            defaults.removeObject(forKey: collapsedMoodKey)
        } else {
            defaults.set(mood.updatedAt, forKey: collapsedMoodKey)
        }
        objectWillChange.send()   // Home re-picks card vs strip immediately
    }

    /// True when the CURRENT partner mood was dismissed to the strip. A newer mood
    /// (different timestamp) reads as not-collapsed → the prominent card returns.
    var partnerMoodCollapsed: Bool {
        guard let mood = partnerMood,
              let d = defaults.object(forKey: collapsedMoodKey) as? Date else { return false }
        return abs(d.timeIntervalSince(mood.updatedAt)) < 1
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

    func setMyMood(_ mood: PartnerMood, customText: String? = nil, note: String? = nil) {
        // Normalize an empty/whitespace custom string to nil so `displayLabel`
        // cleanly falls back to the preset label.
        let custom = customText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCustom = (custom?.isEmpty == false) ? custom : nil
        if let i = moods.firstIndex(where: { $0.userId == currentUserId }) {
            moods[i].mood = mood
            moods[i].customText = normalizedCustom
            moods[i].note = note
            moods[i].updatedAt = Date()
        } else {
            moods.append(MoodStatus(userId: currentUserId, mood: mood,
                                    customText: normalizedCustom, note: note))
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

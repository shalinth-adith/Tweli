//
//  MoodCardPreviews.swift
//  Tweli
//
//  DEBUG ONLY. The whole file is inside `#if DEBUG`, so none of it exists in any
//  distribution build.
//
//  The Home mood card only draws once there is a partner AND a synced mood, and
//  a headless simulator has neither — there is no seeded content anywhere in
//  this app, and the sim cannot inject the taps to create any. This renders the
//  card on its own, with representative inputs, so its layout can be checked in
//  both palettes.
//
//  It renders the CARD, not Home: every input the card has is passed in, so this
//  exercises the real view rather than a copy of it. Values are prefixed
//  `PLACEHOLDER_` and the file is named `…Previews` so the repo's placeholder
//  grep skips it. Nothing is written to storage or pushed anywhere.
//
//  Usage:
//    SIMCTL_CHILD_TWELI_MOOD_CARD=set     — a fresh mood with a note
//    SIMCTL_CHILD_TWELI_MOOD_CARD=old     — a mood from yesterday
//    SIMCTL_CHILD_TWELI_MOOD_CARD=resting — no mood shared yet
//

#if DEBUG

import SwiftUI

struct MoodCardPreviewHarness: View {
    let variant: String
    @Environment(\.colorScheme) private var scheme

    static var requested: String? {
        ProcessInfo.processInfo.environment["TWELI_MOOD_CARD"]
    }

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()

            VStack(spacing: 12) {
                // The banner is included because it is the card's neighbour on
                // Home, and the pair of them is what the timing tag has to read
                // sensibly against — this line says what time it is THERE, the
                // card's tag says when the mood landed HERE.
                PartnerLocalTimeBanner(partnerName: "PLACEHOLDER_Partner",
                                       cityLabel: nil,
                                       timeZoneId: "Asia/Dubai")

                FreshMoodCardView(mood: mood,
                                  partnerName: "PLACEHOLDER_Partner",
                                  partnerInitials: "P",
                                  onTap: {})
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 70)
        }
    }

    private var mood: MoodStatus? {
        switch variant {
        case "resting":
            nil
        case "old":
            stub(updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        default:
            stub(updatedAt: Date().addingTimeInterval(-2 * 3600))
        }
    }

    private func stub(updatedAt: Date) -> MoodStatus {
        var mood = MoodStatus(userId: UUID(), mood: .missingYou,
                              note: "PLACEHOLDER_note — call me on your lunch break")
        mood.updatedAt = updatedAt
        return mood
    }
}

#endif

//
//  FreshMoodCardView.swift
//  Tweli
//
//  The partner's mood as it rests on Home — the hero card of comp L3 / N3.
//  This is the calm state you land on AFTER the full-screen "new mood"
//  interstitial (MoodInterstitialView) is swiped away.
//
//  The card owns ONE thing — the mood: a "From <partner>" eyebrow, the partner
//  avatar + "<partner> feels" + the big mood word, and (if present) an italic
//  note under a hairline. Distance and the meet-date countdown live in their own
//  sibling cards below. Tapping anywhere opens the Moods tab.
//
//  Comp geometry: radius 24, padding 20, eyebrow 11/800 uppercase +0.8 tracking
//  in accentInk, avatar 50pt with an indigo glow, label 11/700 uppercase, mood
//  31/800 at -0.8 tracking, hairline, quote 14 italic.
//

import SwiftUI

struct FreshMoodCardView: View {
    let mood: MoodStatus
    let partnerName: String
    let partnerInitials: String
    /// Tap the card body — open the Moods tab.
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow
            content
            if let note = mood.note, !note.isEmpty { noteRow(note) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard(radius: TweliMetrics.heroRadius, hero: true)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    // MARK: - Eyebrow ("FROM <PARTNER>")

    private var eyebrow: some View {
        Text("From \(partnerName)")
            .font(.system(size: 11, weight: .heavy))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Color.twAccentInk)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.bottom, 16)
    }

    // MARK: - Body (avatar + "<partner> feels" + big mood)

    private var content: some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(TweliGradient.partnerAvatar)
                .frame(width: 50, height: 50)
                .overlay {
                    Text(partnerInitials)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                }
                // Comp: box-shadow 0 0 20px rgba(123,121,255,0.35) — a halo, not
                // a drop shadow, so it sits centred rather than offset.
                .shadow(color: Color.twAccent2.opacity(0.35), radius: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(partnerName) feels")
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Color.twInkTertiary)
                Text(mood.displayLabel)
                    .font(.system(size: 31, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundStyle(Color.twInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    // MARK: - Note (italic, under a hairline)

    private func noteRow(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.twSeparator)
                .frame(height: 1)
            Text("“\(note)”")
                .font(.system(size: 14))
                .italic()
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 15)
        }
        .padding(.top, 17)
    }
}

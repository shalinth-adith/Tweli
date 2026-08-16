//
//  FreshMoodCardView.swift
//  Tweli
//
//  The partner's mood as it rests on Home — the hero card of comp L3 / N3.
//  This is the calm state you land on AFTER the full-screen "new mood"
//  interstitial (MoodInterstitialView) is swiped away.
//
//  The card owns ONE thing — the mood: a "From <partner>" eyebrow with the
//  timing tag opposite it, the partner avatar + "<partner> feels" + the big mood
//  word, and (if present) an italic note under a hairline. Distance and the
//  meet-date countdown live in their own sibling cards below. Tapping anywhere
//  opens the Moods tab.
//
//  Comp geometry: radius 24, padding 20, eyebrow 11/800 uppercase +0.8 tracking
//  in accentInk with a 12/600 tertiary timing tag baseline-aligned opposite it,
//  avatar 50pt with an indigo glow, label 11/700 uppercase, mood 31/800 at -0.8
//  tracking, hairline, quote 14 italic.
//
//  THIS CARD DOES NOT COLLAPSE. The older comp (21a/b) let an acknowledged mood
//  shrink to a one-line strip; L3/N3 replaced that with a card that simply
//  rests. A mood arriving or changing rewrites the words inside — it never
//  changes how much room the card takes, so Home never reflows under the reader.
//

import SwiftUI

struct FreshMoodCardView: View {
    /// `nil` ⇒ the partner has not shared a mood yet. The card still draws, in
    /// its resting state: the layout below it must not jump the first time they
    /// post, and an absent card is indistinguishable from a broken one.
    let mood: MoodStatus?
    let partnerName: String
    let partnerInitials: String
    /// Tap the card body — open the Moods tab.
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow
            content
            if let note = mood?.note, !note.isEmpty { noteRow(note) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tweliCard(radius: TweliMetrics.heroRadius, hero: true)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        // One element, one sentence — VoiceOver should not read this as four
        // unrelated fragments, and the timing tag is meaningless on its own.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        guard let mood else {
            return "\(partnerName) hasn't shared how they're feeling yet"
        }
        let note = mood.note.flatMap { $0.isEmpty ? nil : ", they said \($0)" } ?? ""
        return "From \(partnerName), \(mood.timingTag). \(partnerName) feels \(mood.displayLabel)\(note)"
    }

    // MARK: - Eyebrow ("FROM <PARTNER>" · timing tag)

    /// Comp L3/N3: a baseline-aligned row, eyebrow left, timing right.
    private var eyebrow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("From \(partnerName)")
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.twAccentInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            if let mood {
                // `layoutPriority` so a long partner name loses room before the
                // timing does. "8:12 AM" truncated to "8:1…" would be worse than
                // useless, and the tag is the whole point of this row.
                Text(mood.timingTag)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.twInkTertiary)
                    .lineLimit(1)
                    .fixedSize()
                    .layoutPriority(1)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Body (avatar + "<partner> feels" + big mood)

    private var content: some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(mood == nil
                      ? AnyShapeStyle(Color.twInkTertiary.opacity(0.16))
                      : AnyShapeStyle(TweliGradient.partnerAvatar))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(partnerInitials)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(mood == nil ? Color.twInkQuaternary : .white)
                }
                // Comp: box-shadow 0 0 20px rgba(123,121,255,0.35) — a halo, not
                // a drop shadow, so it sits centred rather than offset. The
                // resting card drops it: a glow around a mood nobody has set
                // reads as new.
                .shadow(color: Color.twAccent2.opacity(mood == nil ? 0 : 0.35), radius: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(mood == nil ? "Nothing shared yet" : "\(partnerName) feels")
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Color.twInkTertiary)

                // The headline slot is filled in both states, at the same size,
                // so the card is exactly as tall before the first mood as after
                // it. That is what stops Home reflowing under the reader.
                Text(mood?.displayLabel ?? "Ask them how\ntheir day is")
                    .font(.system(size: mood == nil ? 22 : 31, weight: .heavy))
                    .tracking(mood == nil ? -0.4 : -0.8)
                    .foregroundStyle(mood == nil ? Color.twInkSecondary : Color.twInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    // Cross-fade the words rather than swapping them: a mood
                    // changing should look like the card thinking, not like the
                    // card being replaced.
                    .contentTransition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: mood?.displayLabel)
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

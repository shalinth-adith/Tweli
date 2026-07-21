//
//  FreshMoodCardView.swift
//  Tweli
//
//  The partner's mood as it rests on Home (designs 21a/b — light/dark). This is
//  the calm state you land on AFTER the full-screen "new mood" interstitial
//  (MoodInterstitialView, designs 22a/b) is swiped away. It is static — NOT
//  swipeable. Two tap targets: the ❤️ N-days chip opens the "When do you meet?"
//  sheet; tapping anywhere else opens the Moods tab.
//

import SwiftUI

struct FreshMoodCardView: View {
    let mood: MoodStatus
    let partnerName: String
    let partnerInitials: String
    /// Days until the reunion (nil ⇒ no meet date set yet → chip prompts to add one).
    let daysRemaining: Int?
    /// Tap the card body — open the Moods tab.
    var onTap: () -> Void
    /// Tap the ❤️ chip — open the "When do you meet?" sheet.
    var onCountdownTap: () -> Void

    @State private var pulsing = false

    var body: some View {
        card
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
            footer
        }
        .padding(EdgeInsets(top: 17, leading: 18, bottom: 15, trailing: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))   // white / #1C1C1E
        .overlay(alignment: .top) {
            // 3px indigo→pink accent bar hugging the top edge.
            LinearGradient(colors: [.twAccent2, .twAccent], startPoint: .leading, endPoint: .trailing)
                .frame(height: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.twAccent.opacity(0.18), radius: 26, x: 0, y: 16)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    // MARK: - Header ("Just updated · now" + ❤️ days chip)

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.twAccent)
                .frame(width: 9, height: 9)
                .scaleEffect(pulsing ? 1 : 0.55)
                .opacity(pulsing ? 1 : 0.5)
            Text("Just updated · \(mood.relativeLabel)")
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .kerning(0.7)
                .foregroundStyle(Color.twAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            countdownChip
        }
        .padding(.bottom, 13)
    }

    private var countdownChip: some View {
        Button(action: onCountdownTap) {
            HStack(spacing: 4) {
                Text("❤️").font(.system(size: 12))
                Text(daysRemaining.map { "\($0) days" } ?? "Set date")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Color.twAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.twAccent.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Body (avatar + mood + note)

    private var content: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.482, green: 0.475, blue: 1.0), .twAccent2],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .overlay(Text(partnerInitials).font(.system(size: 19, weight: .semibold)).foregroundStyle(.white))
                .shadow(color: Color.twAccent2.opacity(0.32), radius: 10, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(partnerName) feels")
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(0.5)
                    .foregroundStyle(.tertiary)
                Text(mood.mood.label)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let note = mood.note, !note.isEmpty {
                    Text("“\(note)”")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5)
                }
            }
        }
    }

    // MARK: - Footer (privacy reassurance)

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.system(size: 11, weight: .semibold))
            Text("Thinking of you across the miles ♡")
                .font(.system(size: 11.5, weight: .semibold))
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(Color(UIColor.separator).opacity(0.5)).frame(height: 1)
        }
    }
}

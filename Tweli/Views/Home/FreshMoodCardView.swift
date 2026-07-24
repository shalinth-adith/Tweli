//
//  FreshMoodCardView.swift
//  Tweli
//
//  The partner's mood as it rests on Home (designs 21a/b — light/dark). This is
//  the calm state you land on AFTER the full-screen "new mood" interstitial
//  (MoodInterstitialView, designs 22a/b) is swiped away.
//
//  Per 21a/b the card owns ONE thing — the mood: a "From <partner>" eyebrow, the
//  partner avatar + "<partner> feels" + the big mood word, and (if present) an
//  italic note under a hairline. Distance and the meet-date countdown live in
//  their own sibling cards below (ClosenessStripView / the Dates card), not here.
//  Tapping anywhere opens the Moods tab.
//

import SwiftUI

struct FreshMoodCardView: View {
    let mood: MoodStatus
    let partnerName: String
    let partnerInitials: String
    /// Tap the card body — open the Moods tab.
    var onTap: () -> Void

    var body: some View {
        card
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow
            content
            if let note = mood.note, !note.isEmpty {
                noteRow(note)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))   // white / #1C1C1E
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.twAccent.opacity(0.12), radius: 24, x: 0, y: 16)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    // MARK: - Eyebrow ("FROM <PARTNER>")

    private var eyebrow: some View {
        Text("From \(partnerName)")
            .font(.system(size: 11, weight: .heavy))
            .textCase(.uppercase)
            .kerning(0.8)
            .foregroundStyle(Color.twAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.bottom, 16)
    }

    // MARK: - Body (avatar + "<partner> feels" + big mood)

    private var content: some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.482, green: 0.475, blue: 1.0), .twAccent2],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 50, height: 50)
                .overlay(Text(partnerInitials).font(.system(size: 21, weight: .semibold)).foregroundStyle(.white))
                .shadow(color: Color.twAccent2.opacity(0.32), radius: 8, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(partnerName) feels")
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(.tertiary)
                Text(mood.displayLabel)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    // MARK: - Note (italic, under a hairline)

    private func noteRow(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Color(UIColor.separator).opacity(0.5)).frame(height: 1)
            Text("“\(note)”")
                .font(.system(size: 14))
                .italic()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 18)   // room for the caption to breathe below the line
        }
        .padding(.top, 18)           // and room above the line, off the mood word
    }
}

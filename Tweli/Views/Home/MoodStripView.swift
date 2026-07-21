//
//  MoodStripView.swift
//  Tweli
//
//  The resting state of a partner's mood on Home (designs 21a/b). After the
//  "new mood" interstitial is swiped or skipped, the mood collapses to this
//  quiet strip at the top of Home; tapping it opens the Moods tab.
//

import SwiftUI
import UIKit

struct MoodStripView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var moods: MoodService

    var body: some View {
        if let mood = moods.partnerMood {
            Button { app.requestedTab = 3 } label: {
                HStack(spacing: 9) {
                    Circle()
                        .fill(Color.twAccent2.opacity(0.5))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Text(app.partner?.initials ?? "?")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        )
                    Text("\(app.partner?.displayName ?? "Your partner")'s feeling \(mood.mood.label.lowercased())")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(Color(UIColor.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

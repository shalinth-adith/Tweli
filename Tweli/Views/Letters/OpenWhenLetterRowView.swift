//
//  OpenWhenLetterRowView.swift
//  Tweli
//

import SwiftUI

struct OpenWhenLetterRowView: View {
    let letter: OpenWhenLetter

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(letter.isOpened ? Color.twAccent2.opacity(0.15) : Color.twAccentSoft)
                    .frame(width: 48, height: 48)
                Image(systemName: letter.isLocked ? "lock.fill"
                                  : (letter.isOpened ? "envelope.open.fill" : "envelope.fill"))
                    .foregroundStyle(letter.isOpened ? Color.twAccent2 : Color.twAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(letter.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                Text(statusText)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(14)
        .tweliCard()
    }

    private var statusText: String {
        if letter.isLocked, let d = letter.unlockDate {
            return "Unlocks \(d.formatted(date: .abbreviated, time: .omitted))"
        }
        if letter.isOpened { return "Opened" }
        return "Tap to open"
    }
}

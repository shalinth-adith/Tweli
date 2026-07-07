//
//  CountdownCardView.swift
//  Tweli
//

import SwiftUI

struct CountdownCardView: View {
    let countdown: CountdownItem
    var onPin: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.twAccent2.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: countdown.category.sfSymbol).foregroundStyle(Color.twAccent2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(countdown.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                Text(countdown.targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(countdown.daysRemaining)")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Color.twAccent)
                Text("days").font(.caption2).foregroundStyle(.tertiary)
            }
            if let onPin {
                Button(action: onPin) {
                    Image(systemName: countdown.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(countdown.isPinned ? Color.twAccent : Color.twInkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .tweliCard()
    }
}

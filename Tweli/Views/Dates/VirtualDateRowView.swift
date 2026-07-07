//
//  VirtualDateRowView.swift
//  Tweli
//

import SwiftUI

struct VirtualDateRowView: View {
    let date: VirtualDateItem
    var onComplete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.twAccent2.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "calendar").foregroundStyle(Color.twAccent2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(date.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                Text(date.whenLabel).font(.caption).foregroundStyle(.secondary)
                if !date.notes.isEmpty {
                    Text(date.notes).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Spacer()
            ChipView(text: date.status.label, tint: date.status.tint)
        }
        .padding(14)
        .tweliCard()
    }
}

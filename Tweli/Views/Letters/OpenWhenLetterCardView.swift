//
//  OpenWhenLetterCardView.swift
//  Tweli
//
//  A single "envelope" card in the Open-When Letters grid. Sealed cards show a
//  decorative flap + unread dot; opened cards use a flat panel with a green check.
//

import SwiftUI

/// The downward "V" envelope flap from the design (clip-path 0,0 → 50%,60% → 100%,0).
struct EnvelopeFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct OpenWhenLetterCardView: View {
    let letter: OpenWhenLetter
    /// Alternating accent so the grid feels lively (even = pink, odd = indigo).
    let accent: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(letter.isOpened ? Color.twElevated2 : Color.twElevated)
                .overlay {
                    if letter.isOpened {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.twSeparator, lineWidth: 1)
                    }
                }
                .shadow(color: letter.isOpened ? .clear : .black.opacity(0.06), radius: 10, x: 0, y: 5)

            // Sealed: decorative flap at the top.
            if !letter.isOpened {
                EnvelopeFlap()
                    .fill(letter.isLocked ? Color.twInkTertiary.opacity(0.25) : accent.opacity(0.18))
                    .frame(height: 46)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            // Opened: green check in the top-right corner.
            if letter.isOpened {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.twSuccess)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(14)
            }

            // Title + status indicator at the bottom.
            VStack(alignment: .leading, spacing: 8) {
                Text(letter.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if letter.isOpened {
                    Text("Opened · read again").font(.caption2).foregroundStyle(.tertiary)
                } else if letter.isLocked {
                    Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.tertiary)
                } else {
                    Circle().fill(accent).frame(width: 8, height: 8)
                }
            }
            .padding(16)
        }
        .frame(height: 140)
    }
}

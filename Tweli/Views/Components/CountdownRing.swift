//
//  CountdownRing.swift
//  Tweli
//
//  Circular progress ring with a big day count in the middle (design 1b small widget).
//

import SwiftUI

struct CountdownRing: View {
    let days: Int
    var progress: Double = 0.5
    var tint: Color = .twAccent
    var lineWidth: CGFloat = 8
    var showsLabel: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.twSeparator, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(days)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                if showsLabel {
                    Text("days")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                }
            }
        }
    }
}

#Preview {
    CountdownRing(days: 21, progress: 0.65)
        .frame(width: 140, height: 140)
        .padding()
}

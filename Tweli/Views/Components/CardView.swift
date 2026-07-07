//
//  CardView.swift
//  Tweli
//

import SwiftUI

/// Generic elevated container matching the design's rounded cards.
struct CardView<Content: View>: View {
    var padding: CGFloat = 16
    var background: Color = .twElevated
    var radius: CGFloat = TweliMetrics.cardRadius
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tweliCard(radius: radius, background: background)
    }
}

/// A section header row ("Today", "Upcoming") with an optional trailing accessory.
struct SectionHeader<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Spacer()
            accessory()
        }
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

//
//  MoodSharingView.swift
//  Tweli
//
//  Matches the design: a soft-accent partner card with a 7-day mood-history bar,
//  then a "How are you feeling?" section of flowing text chips.
//

import SwiftUI

struct MoodSharingView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: MoodService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                partnerCard
                feelingSection
            }
            .padding(TweliMetrics.screenPadding)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Moods")
    }

    // MARK: - Partner mood card (soft accent + 7-day history bar)

    private var partnerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.twAccent)
                    .frame(width: 44, height: 44)
                    .overlay(Text(app.partner?.initials ?? "A").font(.headline).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(app.partner?.displayName ?? "Partner")'s mood").tweliEyebrow(.twAccent)
                    Text(service.partnerMood?.mood.label ?? "—")
                        .font(.system(size: 21, weight: .heavy))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text(service.partnerMood?.relativeLabel ?? "")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(Array(service.partnerWeekMoods.enumerated()), id: \.offset) { _, mood in
                        Capsule().fill(mood.tint).frame(height: 5).frame(maxWidth: .infinity)
                    }
                }
                Text("Last 7 days").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.twAccentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - "How are you feeling?" wrap chips

    private var feelingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How are you feeling?").font(.headline).foregroundStyle(.primary)
            FlowLayout(spacing: 10) {
                ForEach(PartnerMood.allCases) { mood in
                    moodChip(mood)
                }
            }
        }
    }

    private func moodChip(_ mood: PartnerMood) -> some View {
        let selected = service.myMood?.mood == mood
        return Button {
            withAnimation(.snappy) { service.setMyMood(mood) }
        } label: {
            HStack(spacing: 5) {
                if selected { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                Text(mood.label).font(.subheadline.weight(selected ? .bold : .semibold))
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(selected ? .white : Color.twInk)
            .background(selected ? Color.twAccent : Color.twElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: selected ? Color.twAccent.opacity(0.35) : .black.opacity(0.05),
                    radius: selected ? 8 : 4, x: 0, y: selected ? 4 : 1)
        }
        .buttonStyle(.plain)
    }
}

/// Lightweight wrapping layout (flex-wrap) for the mood chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

//
//  MoodSharingView.swift
//  Tweli
//

import SwiftUI

struct MoodSharingView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: MoodService

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                partnerCard
                Text("How are you feeling?").font(.title3.weight(.bold)).padding(.top, 4)
                moodGrid
            }
            .padding(TweliMetrics.screenPadding)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Moods")
    }

    private var partnerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(app.partner?.displayName ?? "Partner") feels").tweliEyebrow(.white.opacity(0.85))
            HStack {
                Text(service.partnerMood?.mood.label ?? "—")
                    .font(.system(size: 30, weight: .heavy))
                Spacer()
                Text(service.partnerMood?.mood.emoji ?? "💗").font(.system(size: 40))
            }
            .foregroundStyle(.white)
            Text("updated \(service.partnerMood?.relativeLabel ?? "recently")")
                .font(.caption).foregroundStyle(.white.opacity(0.85))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TweliGradient.hero)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var moodGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(PartnerMood.allCases) { mood in
                Button { withAnimation(.snappy) { service.setMyMood(mood) } } label: {
                    moodTile(mood)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func moodTile(_ mood: PartnerMood) -> some View {
        let isSelected = service.myMood?.mood == mood
        return HStack(spacing: 10) {
            Text(mood.emoji).font(.title3)
            Text(mood.label).font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Color.twInk)
            Spacer()
            if isSelected { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white) }
        }
        .padding(.horizontal, 14).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.twAccent : Color.twElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

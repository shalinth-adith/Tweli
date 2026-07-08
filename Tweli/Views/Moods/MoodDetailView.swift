//
//  MoodDetailView.swift
//  Tweli
//
//  The mood meter in detail — reached by tapping a mood card on the Moods screen.
//  Shows the current mood plus a labelled 7-day breakdown.
//

import SwiftUI

/// Which person's mood meter to show.
enum MoodTarget: Hashable { case me, partner }

struct MoodDetailView: View {
    let target: MoodTarget
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: MoodService

    // MARK: - Resolved data (live from the service)

    private var isMe: Bool { target == .me }
    private var name: String {
        isMe ? "You" : (app.partner?.displayName ?? "Your partner")
    }
    private var initials: String {
        (isMe ? app.currentUser.initials : app.partner?.initials) ?? "?"
    }
    private var accent: Color { isMe ? .twAccent2 : .twAccent }
    private var currentMood: PartnerMood? {
        (isMe ? service.myMood : service.partnerMood)?.mood
    }
    private var updatedLabel: String {
        (isMe ? service.myMood : service.partnerMood)?.relativeLabel ?? "recently"
    }
    private var week: [PartnerMood] { isMe ? service.myWeekMoods : service.partnerWeekMoods }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                meterCard
                breakdown
            }
            .padding(TweliMetrics.screenPadding)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Mood meter")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle().fill(.white.opacity(0.25)).frame(width: 52, height: 52)
                    .overlay(Text(initials).font(.title3.weight(.bold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text(isMe ? "How you feel" : "\(name) feels").tweliEyebrow(.white.opacity(0.85))
                    Text(currentMood?.label ?? "Not set")
                        .font(.system(size: 30, weight: .heavy)).foregroundStyle(.white)
                }
                Spacer()
                Text(currentMood?.emoji ?? "💗").font(.system(size: 40))
            }
            Text("Updated \(updatedLabel)").font(.caption).foregroundStyle(.white.opacity(0.85))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TweliGradient.hero)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Meter (7 tall bars + weekday labels)

    private var meterCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("This week").tweliEyebrow()
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(week.enumerated()), id: \.offset) { i, mood in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(mood.tint)
                                .frame(height: 64)
                            Text(weekdayLabel(for: i))
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Per-day breakdown

    private var breakdown: some View {
        CardView(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(week.enumerated().reversed()), id: \.offset) { i, mood in
                    HStack(spacing: 12) {
                        Circle().fill(mood.tint).frame(width: 10, height: 10)
                        Text(i == week.count - 1 ? "Today" : weekdayLabel(for: i))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(mood.label).fontWeight(.semibold).foregroundStyle(.primary)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    if i != 0 { Divider().padding(.leading, 38) }
                }
            }
        }
    }

    /// Weekday label for index `i` (last index = today, older toward 0).
    private func weekdayLabel(for i: Int) -> String {
        let daysAgo = (week.count - 1) - i
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}

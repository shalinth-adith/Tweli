//
//  HomeMomentView.swift
//  Tweli
//
//  Home direction 1b — one feeling at a time: a large gradient hero showing the
//  partner's mood + countdown, reminder chips, and two primary actions.
//

import SwiftUI

struct HomeMomentView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var countdowns: CountdownService
    @EnvironmentObject private var moods: MoodService
    @EnvironmentObject private var reminders: ReminderService

    @State private var showAddDate = false

    var body: some View {
        VStack(spacing: 16) {
            heroCard
            reminderChips
            actionRow
        }
        .sheet(isPresented: $showAddDate) { AddVirtualDateView() }
    }

    private var heroCard: some View {
        NavigationLink(value: HomeRoute.missingYou) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Circle()
                        .fill(.white.opacity(0.25))
                        .frame(width: 44, height: 44)
                        .overlay(Text(app.partner?.initials ?? "A").font(.headline).foregroundStyle(.white))
                    Spacer()
                    if let cd = countdowns.pinned {
                        VStack(spacing: 0) {
                            Text("\(cd.daysRemaining)").font(.headline.weight(.heavy))
                            Text("DAYS").font(.system(size: 8, weight: .semibold)).opacity(0.85)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.white.opacity(0.22))
                        .clipShape(Circle())
                    }
                }
                Spacer(minLength: 40)
                Text("\(app.partner?.displayName ?? "Partner") feels").tweliEyebrow(.white.opacity(0.85))
                Text(moods.partnerMood?.mood.label ?? "Missing you")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(.white)
                Text("updated \(moods.partnerMood?.relativeLabel ?? "recently") · tap to send love back")
                    .font(.caption).foregroundStyle(.white.opacity(0.85))
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .leading)
            .background(TweliGradient.hero)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var reminderChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(reminders.today.isEmpty ? reminders.upcoming : reminders.today) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                        Text(r.timeLabel).font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.twElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            NavigationLink(value: HomeRoute.missingYou) {
                labelPill("Send love", "heart.fill", filled: true)
            }.buttonStyle(.plain)
            Button { showAddDate = true } label: {
                labelPill("Plan a date", "calendar", filled: false)
            }.buttonStyle(.plain)
        }
    }

    private func labelPill(_ title: String, _ icon: String, filled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title).fontWeight(.bold)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .foregroundStyle(filled ? .white : Color.twInk)
        .background(filled ? Color.twAccent : Color.twElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(filled ? .clear : Color.twSeparator, lineWidth: 1)
        )
    }
}

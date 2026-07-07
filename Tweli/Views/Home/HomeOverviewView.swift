//
//  HomeOverviewView.swift
//  Tweli
//
//  Home direction 1a — data-forward: countdown hero, mood + ping, next date,
//  today's reminders, and a quick-action grid.
//

import SwiftUI

struct HomeOverviewView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var countdowns: CountdownService
    @EnvironmentObject private var moods: MoodService
    @EnvironmentObject private var dates: VirtualDateService
    @EnvironmentObject private var reminders: ReminderService

    @State private var showAddReminder = false
    @State private var showAddLetter = false
    @State private var showAddDate = false

    var body: some View {
        VStack(spacing: TweliMetrics.cardSpacing) {
            countdownHero
            moodAndPingRow
            nextDateCard
            remindersPreview
            quickActions
        }
        .sheet(isPresented: $showAddReminder) { AddReminderView() }
        .sheet(isPresented: $showAddLetter) { AddOpenWhenLetterView() }
        .sheet(isPresented: $showAddDate) { AddVirtualDateView() }
    }

    // MARK: - Countdown hero

    @ViewBuilder private var countdownHero: some View {
        if let cd = countdowns.pinned {
            NavigationLink(value: HomeRoute.countdown) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(cd.title).tweliEyebrow(.white.opacity(0.85))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(cd.daysRemaining)")
                            .font(.system(size: 54, weight: .heavy))
                        Text("days").font(.title3.weight(.semibold)).opacity(0.9)
                    }
                    ProgressView(value: cd.progress)
                        .tint(.white)
                        .background(.white.opacity(0.3))
                    Text("Anniversary in \(anniversaryDays) days · her birthday in \(birthdayDays)")
                        .font(.caption).opacity(0.85)
                        .padding(.top, 2)
                }
                .foregroundStyle(.white)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.twAccent)
                .clipShape(RoundedRectangle(cornerRadius: TweliMetrics.heroRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var anniversaryDays: Int {
        countdowns.countdowns.first { $0.category == .anniversary }?.daysRemaining ?? 37
    }
    private var birthdayDays: Int {
        countdowns.countdowns.first { $0.category == .birthday }?.daysRemaining ?? 12
    }

    // MARK: - Mood + ping

    private var moodAndPingRow: some View {
        HStack(spacing: 12) {
            CardView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(app.partner?.displayName ?? "Partner") feels").tweliEyebrow()
                    Text(moods.partnerMood?.mood.label ?? "—")
                        .font(.headline).foregroundStyle(.primary)
                    Text(moods.partnerMood?.relativeLabel ?? "")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            NavigationLink(value: HomeRoute.missingYou) {
                CardView(background: .twAccentSoft) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Send a ping").tweliEyebrow(.twAccent)
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                            Text("Missing you").fontWeight(.bold)
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.twAccent)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Next date

    @ViewBuilder private var nextDateCard: some View {
        if let date = dates.next {
            CardView {
                HStack(spacing: 12) {
                    iconTile("calendar", tint: .twAccent2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next virtual date").tweliEyebrow()
                        Text("\(date.title) · \(date.whenLabel)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Reminders preview

    private var remindersPreview: some View {
        CardView(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Today").tweliEyebrow().padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)
                if reminders.today.isEmpty {
                    Text("No reminders today")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(16)
                } else {
                    ForEach(reminders.today.prefix(3)) { r in
                        HStack(spacing: 12) {
                            Button { withAnimation { reminders.toggleDone(r) } } label: {
                                Image(systemName: r.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(r.isCompleted ? Color.twSuccess : Color.twInkTertiary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            Text(r.title)
                                .font(.subheadline)
                                .strikethrough(r.isCompleted)
                                .foregroundStyle(r.isCompleted ? .tertiary : .primary)
                            Spacer()
                            Text(r.timeLabel).font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        if r.id != reminders.today.prefix(3).last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 10) {
            NavigationLink(value: HomeRoute.missingYou) {
                quickTile("heart.fill", "Ping", .twAccent)
            }.buttonStyle(.plain)
            Button { showAddLetter = true } label: { quickTile("envelope.fill", "Letter", .twAccent2) }.buttonStyle(.plain)
            Button { showAddDate = true } label: { quickTile("calendar", "Plan date", .twAccent2) }.buttonStyle(.plain)
            Button { showAddReminder = true } label: { quickTile("plus", "Add task", .twInkSecondary) }.buttonStyle(.plain)
        }
    }

    private func quickTile(_ icon: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: icon).font(.title3).foregroundStyle(tint)
            }
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func iconTile(_ icon: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.15))
                .frame(width: 44, height: 44)
            Image(systemName: icon).foregroundStyle(tint)
        }
    }
}

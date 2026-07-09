//
//  HomeMomentView.swift
//  Tweli
//
//  The Home dashboard (design 1b — "Moment"): one feeling at a time. A swipeable
//  mood hero (partner ⇄ you), the "Until we meet again" reunion countdown pulled
//  in from the retired Overview layout, today's checkable reminders, and two
//  primary actions.
//

import SwiftUI

struct HomeMomentView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var countdowns: CountdownService
    @EnvironmentObject private var moods: MoodService
    @EnvironmentObject private var reminders: ReminderService

    @State private var showAddDate = false
    @State private var heroPage = 0

    var body: some View {
        VStack(spacing: 16) {
            heroCarousel
            pagingDots
            countdownCard
            remindersCard
            actionRow
        }
        .sheet(isPresented: $showAddDate) { AddVirtualDateView() }
    }

    // MARK: - Swipeable mood hero

    private var heroCarousel: some View {
        TabView(selection: $heroPage) {
            // Page 0 — partner's feeling (tap to send love back)
            NavigationLink(value: HomeRoute.missingYou) {
                heroCard(
                    initials: app.partner?.initials ?? "A",
                    eyebrow: "\(app.partner?.displayName ?? "Partner") feels",
                    mood: moods.partnerMood?.mood.label ?? "Missing you",
                    subtitle: "updated \(moods.partnerMood?.relativeLabel ?? "recently") · tap to send love back"
                )
            }
            .buttonStyle(.plain)
            .tag(0)

            // Page 1 — your own feeling
            heroCard(
                initials: app.currentUser.initials,
                eyebrow: "You feel",
                mood: moods.myMood?.mood.label ?? "—",
                subtitle: "updated \(moods.myMood?.relativeLabel ?? "recently") · swipe back for \(app.partner?.displayName ?? "them")"
            )
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 300)
    }

    private func heroCard(initials: String, eyebrow: String, mood: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Circle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 44, height: 44)
                    .overlay(Text(initials).font(.headline).foregroundStyle(.white))
                Spacer()
                if let cd = countdowns.pinned {
                    VStack(spacing: 0) {
                        Text("\(cd.daysRemaining)").font(.system(size: 18, weight: .heavy))
                        Text("DAYS").font(.system(size: 8, weight: .semibold)).opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.white.opacity(0.22))
                    .clipShape(Circle())
                }
            }
            Spacer(minLength: 40)
            Text(eyebrow).tweliEyebrow(.white.opacity(0.85))
            Text(mood)
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption).foregroundStyle(.white.opacity(0.85))
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .leading)
        .background(TweliGradient.hero)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private var pagingDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .fill(heroPage == i ? Color.twAccent : Color.twInkTertiary)
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Until we meet again (reunion countdown, from Overview)

    @ViewBuilder private var countdownCard: some View {
        if let cd = countdowns.pinned {
            NavigationLink(value: HomeRoute.countdown) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(cd.title).tweliEyebrow(.white.opacity(0.85))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(cd.daysRemaining)")
                            .font(.system(size: 44, weight: .heavy))
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
                .background(Color.twAccent2)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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

    // MARK: - Today's reminders (checkable)

    private var remindersCard: some View {
        CardView(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Today").tweliEyebrow()
                    Spacer()
                    if !reminders.today.isEmpty {
                        Text(todayCountLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.twAccent2)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)

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

    private var todayCountLabel: String {
        let items = reminders.today
        let done = items.filter { $0.isCompleted }.count
        return "\(done)/\(items.count)"
    }

    // MARK: - Actions

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

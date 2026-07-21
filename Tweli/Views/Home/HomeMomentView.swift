//
//  HomeMomentView.swift
//  Tweli
//
//  The Home dashboard (designs 21a/b — light/dark). One quiet screen: the
//  partner's fresh mood as an inline swipeable card that collapses to a strip,
//  followed by today's checkable reminders. The greeting header lives in HomeView.
//

import SwiftUI

struct HomeMomentView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var moods: MoodService
    @EnvironmentObject private var reminders: ReminderService

    var body: some View {
        VStack(spacing: 16) {
            moodMoment
            remindersCard
        }
    }

    // MARK: - Partner's mood (static resting card — the swipe lives on the interstitial)

    @ViewBuilder private var moodMoment: some View {
        if let mood = moods.partnerMood {
            FreshMoodCardView(
                mood: mood,
                partnerName: app.partner?.displayName ?? "Your partner",
                partnerInitials: app.partner?.initials ?? "?",
                onTap: { app.requestedTab = 3 }   // open the Moods tab
            )
        }
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
}

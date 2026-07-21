//
//  PartnerSpaceView.swift
//  Tweli
//

import SwiftUI

struct PartnerSpaceView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var reminders: ReminderService
    @EnvironmentObject private var countdowns: CountdownService

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if couple.partner != nil {
                    coupleHeader
                    statsRow
                    if let cd = countdowns.pinned { sharedCountdown(cd) }
                    connectionCard
                } else {
                    waitingState
                }
            }
            .padding(TweliMetrics.screenPadding)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Partner Space")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Paired state

    private var coupleHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: -14) {
                avatar(app.currentUser.initials, .twAccent2)
                avatar(couple.partner?.initials ?? "?", .twAccent)
            }
            Text(couple.coupleSpace?.title ?? "Our Space")
                .font(.title2.weight(.bold))
            if let since = couple.coupleSpace?.createdAt {
                Text("Together since \(since.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func avatar(_ initials: String, _ color: Color) -> some View {
        Circle().fill(color).frame(width: 68, height: 68)
            .overlay(Text(initials).font(.title2.weight(.bold)).foregroundStyle(.white))
            .overlay(Circle().strokeBorder(Color.twBackground, lineWidth: 3))
    }

    /// Only real, derivable numbers here — no invented streaks.
    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile("\(reminders.reminders.count)", "Shared reminders", .twAccent2)
            statTile("\(reminders.today.filter { $0.isCompleted }.count)", "Done today", .twSuccess)
            if let days = daysTogether {
                statTile("\(days)", "Days together", .twAccent)
            }
        }
    }

    /// Whole days since the space was created; nil until we have that date.
    private var daysTogether: Int? {
        guard let since = couple.coupleSpace?.createdAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: since, to: Date()).day ?? 0
        return max(0, days)
    }

    private func statTile(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.weight(.heavy)).foregroundStyle(tint)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .tweliCard()
    }

    /// The reunion countdown, tappable into the full CountdownView. This is the
    /// entry point to countdown management now that Home (designs 21a/b) no longer
    /// carries the countdown card.
    private func sharedCountdown(_ cd: CountdownItem) -> some View {
        NavigationLink(value: HomeRoute.countdown) {
            CardView {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cd.title).tweliEyebrow()
                        Text("\(cd.daysRemaining) days to go").font(.headline).foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: cd.category.sfSymbol).font(.title2).foregroundStyle(Color.twAccent)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var connectionCard: some View {
        CardView {
            HStack(spacing: 10) {
                Circle().fill(Color.twSuccess).frame(width: 10, height: 10)
                Text("Connected").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer()
                Text("iCloud").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Unpaired state (honest: no phantom partner, no fake "Connected")

    private var waitingState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.twAccent2.opacity(0.15)).frame(width: 76, height: 76)
                Image(systemName: couple.awaitingPartner ? "hourglass" : "heart.circle")
                    .font(.system(size: 30)).foregroundStyle(Color.twAccent2)
            }
            .padding(.top, 24)

            Text(couple.awaitingPartner ? "Waiting for your partner" : "No partner yet")
                .font(.title3.weight(.bold)).foregroundStyle(.primary)

            Text(couple.awaitingPartner
                 ? "They'll appear here the moment they open your invite."
                 : "Invite your partner from Settings to start sharing your space.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }
}

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
                coupleHeader
                statsRow
                if let cd = countdowns.pinned { sharedCountdown(cd) }
                connectionCard
            }
            .padding(TweliMetrics.screenPadding)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Partner Space")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var coupleHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: -14) {
                avatar(app.currentUser.initials, .twAccent2)
                avatar(couple.partner?.initials ?? "?", .twAccent)
            }
            Text(couple.coupleSpace?.title ?? "Our Space")
                .font(.title2.weight(.bold))
            Text("Together since \(couple.coupleSpace?.createdAt.formatted(date: .abbreviated, time: .omitted) ?? "")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func avatar(_ initials: String, _ color: Color) -> some View {
        Circle().fill(color).frame(width: 68, height: 68)
            .overlay(Text(initials).font(.title2.weight(.bold)).foregroundStyle(.white))
            .overlay(Circle().strokeBorder(Color.twBackground, lineWidth: 3))
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile("\(reminders.reminders.count)", "Shared reminders", .twAccent2)
            statTile("\(reminders.today.filter { $0.isCompleted }.count)", "Done today", .twSuccess)
            statTile("7", "Day streak", .twAccent)
        }
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

    private func sharedCountdown(_ cd: CountdownItem) -> some View {
        CardView {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cd.title).tweliEyebrow()
                    Text("\(cd.daysRemaining) days to go").font(.headline).foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: cd.category.sfSymbol).font(.title2).foregroundStyle(Color.twAccent)
            }
        }
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
}

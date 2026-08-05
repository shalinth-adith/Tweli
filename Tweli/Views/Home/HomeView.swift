//
//  HomeView.swift
//  Tweli
//
//  Home dashboard container. Hosts the custom header (greeting + avatar/gear),
//  the "Moment" dashboard, and the navigation routes for the screens the design
//  reaches from Home (Countdown, Missing You, Partner, Settings).
//

import SwiftUI

enum HomeRoute: Hashable { case countdown, missingYou, partner, settings }

struct HomeView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Comp E1 — say the data is stale before showing it, so the mood
                // card below reads as history rather than as now.
                if !app.cloud.accountAvailable && couple.isConnected { OfflineBanner() }
                header
                if couple.awaitingPartner { waitingBanner }
                HomeMomentView()
            }
            .padding(.horizontal, TweliMetrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { app.revealFreshMoodIfAny() }
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .countdown: CountdownView()
            case .missingYou: MissingYouView()
            case .partner: PartnerSpaceView()
            case .settings: SettingsView()
            }
        }
    }

    // MARK: - Header

    /// "Thursday, good afternoon" — weekday + the time-of-day greeting (designs 21a/b).
    private var dayGreeting: String {
        let weekday = Date().formatted(.dateTime.weekday(.wide))
        return "\(weekday), \(app.greeting.lowercased())"
    }

    private var hasName: Bool {
        !app.currentUser.displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Comp L3/N3: greeting 13/600 secondary, name 28/800 at -0.6 tracking, and
    /// on the right YOUR OWN avatar in the pink gradient — the near end of the
    /// thread. It is the entry point to Our space (the comp has no gear icon).
    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayGreeting)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.twInkSecondary)
                // Before the user has told us their name there is nothing
                // honest to print here, so the greeting stands alone rather
                // than leaving a blank line under it.
                Text(hasName ? app.currentUser.displayName : "Our space")
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(Color.twInk)
            }
            Spacer()
            NavigationLink(value: HomeRoute.settings) {
                Circle()
                    .fill(TweliGradient.meAvatar)
                    .frame(width: 38, height: 38)
                    .overlay {
                        // No initials yet → the app's own mark, never a blank disc.
                        if hasName {
                            Text(app.currentUser.initials)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Our space")
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Waiting for partner

    /// Shown to the space owner until the invited person accepts the share.
    private var waitingBanner: some View {
        NavigationLink(value: HomeRoute.partner) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.twAccent2.opacity(0.15)).frame(width: 40, height: 40)
                    Image(systemName: "hourglass").foregroundStyle(Color.twAccent2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Waiting for your partner to join")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.twInk)
                    Text("They'll appear here once they open your invite.")
                        .font(.caption).foregroundStyle(Color.twInkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.twInkTertiary)
            }
            .padding(14)
            .background(Color.twElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

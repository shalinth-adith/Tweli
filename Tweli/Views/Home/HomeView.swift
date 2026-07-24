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

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayGreeting)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(app.currentUser.displayName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            HStack(spacing: 12) {
                NavigationLink(value: HomeRoute.settings) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)   // no tinted glass chrome behind the icon
                NavigationLink(value: HomeRoute.partner) {
                    avatar(couple.partner)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func avatar(_ user: UserProfile?) -> some View {
        Circle()
            .fill(LinearGradient(colors: [Color(red: 0.482, green: 0.475, blue: 1.0), .twAccent2],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 38, height: 38)
            .overlay(
                Text(user?.initials ?? "?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            )
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
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text("They'll appear here once they open your invite.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color.twElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

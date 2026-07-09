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

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.greeting)
                    .font(.subheadline)
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
                NavigationLink(value: HomeRoute.partner) {
                    avatar(couple.partner)
                }
            }
        }
    }

    private func avatar(_ user: UserProfile?) -> some View {
        Circle()
            .fill(Color.twAccent2)
            .frame(width: 42, height: 42)
            .overlay(
                Text(user?.initials ?? "?")
                    .font(.headline)
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

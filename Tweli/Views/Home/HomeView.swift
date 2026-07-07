//
//  HomeView.swift
//  Tweli
//
//  Home dashboard container. Hosts the custom header (greeting + avatar/gear),
//  the Overview/Moment style toggle, and the navigation routes for the screens
//  the design reaches from Home (Countdown, Missing You, Partner, Settings).
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
                styleToggle
                if app.homeStyle == .overview {
                    HomeOverviewView()
                } else {
                    HomeMomentView()
                }
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

    // MARK: - Style toggle (Overview / Moment)

    private var styleToggle: some View {
        HStack(spacing: 4) {
            ForEach(HomeStyle.allCases) { style in
                Button {
                    withAnimation(.snappy) { app.homeStyle = style }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: style.sfSymbol).font(.caption)
                        Text(style.label).font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(app.homeStyle == style ? .white : Color.twInkSecondary)
                    .background(app.homeStyle == style ? Color.twAccent : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.twElevated)
        .clipShape(Capsule())
    }
}

//
//  HomeView.swift
//  Tweli
//
//  Home dashboard container. Hosts the custom header (greeting + avatar/gear),
//  the "Moment" dashboard, and the navigation routes for the screens the design
//  reaches from Home (Countdown, Missing You, Partner, Settings).
//

import SwiftUI
import UIKit

enum HomeRoute: Hashable { case countdown, missingYou, partner, settings }

struct HomeView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService

    @State private var copiedCode = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Comp E1 — say the data is stale before showing it, so the mood
                // card below reads as history rather than as now.
                if !app.cloud.accountAvailable && couple.isConnected { OfflineBanner() }
                header
                if couple.awaitingPartner {
                    waitingCard
                    meanwhileCard
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

    // MARK: - Waiting for partner (comp E5)

    /// The comp calls this "half a thread": your dot lit, theirs still a dashed
    /// outline. It carries the invite code and one gentle thing to do while you
    /// wait, so an empty space still offers something.
    private var waitingCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Circle()
                    .fill(TweliGradient.meAvatar)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Text(app.currentUser.initials.isEmpty ? "·" : app.currentUser.initials)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.twAccent.opacity(0.3), radius: 8, y: 5)
                    .zIndex(1)

                // The thread not yet tied.
                Rectangle()
                    .fill(Color.twInkTertiary.opacity(0.35))
                    .frame(width: 40, height: 1.5)
                    .mask {
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { _ in Rectangle().frame(width: 4) }
                        }
                    }

                Circle()
                    .strokeBorder(Color.twInkQuaternary,
                                  style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Text("?")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Color.twInkQuaternary)
                    }
            }

            Text(waitingHeadline)
                .font(.system(size: 20, weight: .heavy))
                .tracking(-0.4)
                .foregroundStyle(Color.twInk)
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            Text("Your space is ready and waiting. The moment they enter the code, everything here comes alive.")
                .font(.system(size: 13.5))
                .lineSpacing(3)
                .foregroundStyle(Color.twInkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            // The code that actually redeems, not CoupleSpace.inviteCode.
            if let code = app.cloud.activePairCode {
                ShareLink(item: inviteMessage(code)) {
                    Text("Resend the invite")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.twAccentInk,
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .shadow(color: Color.twAccent.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 20)

                HStack(spacing: 8) {
                    Text("Code")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.twInkTertiary)
                    Text(FirebaseService.formatPairCode(code))
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(Color.twInk)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.twFieldFill,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Button(copiedCode ? "Copied" : "Copy") {
                        UIPasteboard.general.string = FirebaseService.formatPairCode(code)
                        withAnimation { copiedCode = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            withAnimation { copiedCode = false }
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.twInfo)
                }
                .padding(.top, 14)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .tweliCard(radius: 24)
    }

    private var waitingHeadline: String {
        let name = couple.partner?.displayName ?? ""
        return name.isEmpty ? "They haven't joined yet" : "\(name) hasn't joined yet"
    }

    private func inviteMessage(_ code: String) -> String {
        """
        💞 Join me on Tweli!

        Open Tweli ▸ Join a space ▸ enter code: \(FirebaseService.formatPairCode(code))
        """
    }

    /// Comp E5's "Meanwhile" nudge — an empty space still offers something to do.
    private var meanwhileCard: some View {
        Button { app.requestedTab = 3 } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Meanwhile").tweliEyebrow(Color.twInkQuaternary)
                Text("Write them a letter now — it'll be the first thing waiting when they walk in. ♥")
                    .font(.system(size: 14, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(Color.twInkSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.twElevated.opacity(0.65),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

//
//  OnboardingView.swift
//  Tweli
//

import SwiftUI

struct OnboardingView: View {
    @State private var path: [OnboardingViewModel.Mode] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 20) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(TweliGradient.hero)
                        .frame(width: 96, height: 96)
                    Image(systemName: "heart.fill").font(.system(size: 44, weight: .bold)).foregroundStyle(.white)
                }
                VStack(spacing: 10) {
                    Text("Remember things together")
                        .font(.system(size: 30, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text("Shared reminders and care moments for you and your partner.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                Spacer()
                VStack(spacing: 12) {
                    PrimaryButton(title: "Create Partner Space", systemImage: "plus.circle.fill") {
                        path.append(.create)
                    }
                    PrimaryButton(title: "Join Partner Space", systemImage: "link", filled: false) {
                        path.append(.join)
                    }
                    Text("Built for the little things love should not forget.")
                        .font(.caption).foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, TweliMetrics.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Color.twBackground.ignoresSafeArea())
            .navigationDestination(for: OnboardingViewModel.Mode.self) { mode in
                CreatePartnerSpaceView(mode: mode)
            }
        }
    }
}

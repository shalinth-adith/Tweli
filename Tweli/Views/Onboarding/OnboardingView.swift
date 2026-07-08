//
//  OnboardingView.swift
//  Tweli
//
//  Entry / welcome screen (design 7a): two dots meeting at a heart, wordmark,
//  tagline, and the two entry actions — with gentle staggered motion.
//

import SwiftUI

struct OnboardingView: View {
    @State private var path: [OnboardingViewModel.Mode] = []
    @State private var appear = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Spacer()

                // Two dots meeting at a heart
                HStack(spacing: 10) {
                    dot(Color.twAccent2)
                        .offset(x: appear ? 0 : -34)
                        .opacity(appear ? 1 : 0)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.twAccent)
                        .scaleEffect(appear ? 1 : 0.2)
                        .opacity(appear ? 1 : 0)
                    dot(Color(red: 1, green: 0.42, blue: 0.54))
                        .offset(x: appear ? 0 : 34)
                        .opacity(appear ? 1 : 0)
                }
                .padding(.bottom, 30)

                // Wordmark + tagline
                VStack(spacing: 10) {
                    Text("Tweli")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(.primary)
                    Text("Two hearts. One space.\nAny distance.")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 14)

                Spacer()
                Spacer()

                // Actions
                VStack(spacing: 12) {
                    PrimaryButton(title: "Create your space") { path.append(.create) }
                    Button { path.append(.join) } label: {
                        Text("I already have an account")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.twAccent)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .opacity(appear ? 1 : 0)
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.twBackground.ignoresSafeArea())
            .navigationDestination(for: OnboardingViewModel.Mode.self) { mode in
                CreatePartnerSpaceView(mode: mode)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.15)) { appear = true }
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 13, height: 13)
    }
}

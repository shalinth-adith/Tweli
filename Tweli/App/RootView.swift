//
//  RootView.swift
//  Tweli
//
//  Top-level routing: Splash → (Onboarding if not connected) → MainTabView.
//  With mock data the couple space is pre-connected, so the app opens on the
//  dashboard; Onboarding is reachable after "disconnect" in Settings.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService

    var body: some View {
        ZStack {
            if app.showSplash {
                SplashView()
                    .transition(.opacity)
            } else if couple.isConnected {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .task {
            // Brief splash, then reveal the app.
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeInOut(duration: 0.45)) { app.showSplash = false }
        }
    }
}

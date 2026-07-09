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
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var couple: CoupleSpaceService

    var body: some View {
        ZStack {
            if app.showSplash {
                SplashView()
                    .transition(.opacity)
            } else if !auth.isSignedIn {
                SignInView()
                    .transition(.opacity)
            } else if !couple.isConnected {
                RoomSetupView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.isSignedIn)
        .animation(.easeInOut(duration: 0.35), value: couple.isConnected)
        .sheet(item: $app.pendingInvite) { invite in
            JoinConfirmView(invite: invite)
                .environmentObject(app)
        }
        .task {
            // Let the entry animation play (dots + thread + wordmark land ~2.4s),
            // then reveal the app. (Notification permission is asked once the user
            // reaches the main app — see MainTabView.)
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation(.easeInOut(duration: 0.5)) { app.showSplash = false }
        }
    }
}

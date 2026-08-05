//
//  RootView.swift
//  Tweli
//
//  Top-level routing: Splash → (Onboarding if not connected) → MainTabView,
//  with comp E6 ("… left the space") taking over the whole window when the
//  partner walks out. A fresh install has no couple space, so it runs the full
//  entry flow; onboarding is reachable again after "Leave this space".
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var theme: ThemeService

    var body: some View {
        ZStack {
            if app.showSplash {
                SplashView()
                    .transition(.opacity)
            } else if let failure = app.fatalSyncError {
                // Comp E8. Only unrecoverable sync failures land here; being
                // offline shows the E1 banner on Home instead.
                SomethingSnappedView(detail: failure) { app.retryAfterFatalError() }
                    .transition(.opacity)
            } else if let goneName = app.partnerLeftName {
                // Comp E6. Sits above the tab bar rather than inside it: the
                // space is half a thread now, and the tabs would be lying.
                PartnerLeftView(partnerName: goneName)
                    .transition(.opacity)
            } else if !auth.isSignedIn {
                SignInView()
                    .transition(.opacity)
            } else if !couple.hasCompletedAboutYou {
                AboutYouView()
                    .transition(.opacity)
            } else if !couple.isConnected {
                RoomSetupView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        // Our space → Theme. `nil` (Auto) follows the system. SwiftUI pushes this
        // into the trait collection, so every dynamic color in DesignSystem.swift
        // resolves to the L (light) or N (dark) palette.
        .preferredColorScheme(theme.theme.colorScheme)
        .animation(.easeInOut(duration: 0.35), value: auth.isSignedIn)
        .animation(.easeInOut(duration: 0.35), value: couple.hasCompletedAboutYou)
        .animation(.easeInOut(duration: 0.35), value: couple.isConnected)
        .animation(.easeInOut(duration: 0.35), value: app.partnerLeftName)
        .animation(.easeInOut(duration: 0.35), value: app.fatalSyncError)
        .sheet(item: $app.pendingInvite) { invite in
            JoinConfirmView(invite: invite)
                .environmentObject(app)
        }
        .fullScreenCover(isPresented: $app.showJoiningWaiter) {
            JoiningView()
                .environmentObject(app)
                .environmentObject(couple)
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

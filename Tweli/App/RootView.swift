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
                // The splash owns its own timing and reports when the comp's
                // sequence has finished — the root must not cut it short. It
                // hands over at full opacity; the cross-fade below is the only
                // transition, so the screen never dips through empty background.
                SplashView { withAnimation(.easeInOut(duration: 0.45)) { app.showSplash = false } }
                    .transition(.opacity)
            } else if let failure = app.fatalSyncError {
                // Comp E8. Only unrecoverable sync failures land here; being
                // offline shows the E1 banner on Home instead.
                SomethingSnappedView(detail: failure) { app.retryAfterFatalError() }
                    .transition(.opacity)
            } else if app.restorePhase == .restoring {
                // Comps K2 / KL2. Ahead of the ordinary routing on purpose:
                // while the space is being re-bound the app is briefly in a
                // state that LOOKS like "signed in, no space", and the branches
                // below would flash Start-or-join over a thread that is on its
                // way back.
                RestoringView()
                    .transition(.opacity)
            } else if app.restorePhase == .rejoined, let summary = app.restoreSummary {
                WelcomeBackView(summary: summary)                          // K3
                    .transition(.opacity)
            } else if app.restorePhase == .pairGone, let gone = app.pairGone {
                // K5 / KL5, and it must outrank E6 below. Both describe the same
                // departure; the difference is that E6 speaks in the present
                // tense ("… left the space") because the user was watching, and
                // this one has to say WHEN, because they weren't.
                PairGoneView(detail: gone)                                 // K5
                    .transition(.opacity)
            } else if app.restorePhase == .cleanup {
                ReinstallCleanupView()                                     // K4
                    .transition(.opacity)
            } else if let goneName = app.partnerLeftName {
                // Comp E6. Sits above the tab bar rather than inside it: the
                // space is half a thread now, and the tabs would be lying.
                PartnerLeftView(partnerName: goneName)
                    .transition(.opacity)
            } else if app.showTutorial {
                // Comp 0Z. Ahead of sign-in on purpose: it is the only chance to
                // say what Tweli is before asking for an identity — and the
                // invited partner, who never went looking for this app, is the
                // one who most needs to be told.
                TutorialView { app.finishTutorial() }
                    .transition(.opacity)
            } else if !auth.isSignedIn {
                // K1 / KL1 when this device has run Tweli before, G1 otherwise.
                SignInView(returning: app.isReinstall)
                    .transition(.opacity)
            } else if !couple.hasCompletedAboutYou {
                // Comps X1–X6. One question per screen on first run; AboutYouView
                // is still the Settings editor, where a single form is right
                // because the user came to change one specific thing.
                ProfileFlowView()
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
        .animation(.easeInOut(duration: 0.35), value: app.restorePhase)

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
            // Recover a space this device has no local record of BEFORE the
            // splash hands over, so a returning user never sees Start-or-join
            // flash up over a space they are still a member of.
            //
            // Skipped on a reinstall: there the recovery is not a silent repair
            // but the screen itself (K2), and doing it here first would leave
            // that screen with nothing left to find — including the `createdAt`
            // K3 needs for "Paired 214 days".
#if DEBUG
            RestoreCapture.applyIfNeeded(to: app)
#endif
            guard !app.isReinstall else { return }
            await app.recoverSpaceIfNeeded()
        }
        .task {
            // Safety net only. SplashView normally dismisses itself the moment
            // its sequence ends (~4.5s); this guards against the view never
            // appearing at all, which would otherwise strand the app on it.
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if app.showSplash { app.showSplash = false }
        }
    }
}

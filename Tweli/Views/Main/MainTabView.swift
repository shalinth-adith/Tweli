//
//  MainTabView.swift
//  Tweli
//
//  The five-tab bar from the design: Home · Reminders · Dates · Moods · Letters.
//  Countdown / Missing You / Partner / Settings are pushed or presented from Home.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var app: AppViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = 0

    private var interstitialUp: Bool { app.freshMood != nil }

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                NavigationStack { HomeView() }
                    .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)

                NavigationStack { ReminderListView() }
                    .tabItem { Label("Reminders", systemImage: "checklist") }.tag(1)

                NavigationStack { VirtualDatePlannerView() }
                    .tabItem { Label("Dates", systemImage: "calendar") }.tag(2)

                NavigationStack { MoodSharingView() }
                    .tabItem { Label("Moods", systemImage: "face.smiling") }.tag(3)

                NavigationStack { OpenWhenLettersView() }
                    .tabItem { Label("Letters", systemImage: "envelope.fill") }.tag(4)
            }
            // Home dims + shrinks behind the mood interstitial ("stepping in").
            .scaleEffect(interstitialUp ? 0.94 : 1)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: interstitialUp)

            if let mood = app.freshMood {
                MoodInterstitialView(
                    mood: mood,
                    partnerName: app.partner?.displayName ?? "Your partner",
                    partnerInitials: app.partner?.initials ?? "?",
                    onOpenMoods: { app.dismissFreshMood(openMoods: true) },
                    onDismiss: { app.dismissFreshMood(openMoods: false) }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: interstitialUp)
        .onChange(of: app.requestedTab) { _, newValue in
            if let tab = newValue { selection = tab; app.requestedTab = nil }
        }
        .onChange(of: scenePhase) { _, phase in
            // Returning to the foreground can surface a mood posted while away, and
            // is our once-an-hour trigger to refresh our own shared location.
            if phase == .active {
                app.revealFreshMoodIfAny()
                app.locationService.refreshIfStale()
            }
        }
        .onAppear {
            // Consume a deep link that arrived before this view began observing
            // (e.g. cold launch straight from the widget).
            if let tab = app.requestedTab { selection = tab; app.requestedTab = nil }
            app.revealFreshMoodIfAny()
        }
        .task {
            // Ask for notification permission once the user is in the app, then
            // schedule all reminder + countdown alerts (guarded to run once).
            await app.notifications.requestAuthorization()
            app.bootstrapNotifications()
            app.syncNow()   // pull any CloudKit changes for the couple space
            app.locationService.refreshIfStale()   // refresh our shared location if stale
        }
    }
}

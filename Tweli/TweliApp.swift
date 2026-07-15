//
//  TweliApp.swift
//  Tweli
//
//  App entry point. Creates the AppViewModel composition root and injects it
//  (plus every service) into the environment so screens can observe their data.
//

import SwiftUI

@main
struct TweliApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    // Route app-delegate callbacks into the app.
                    appDelegate.onRemoteChange = { app.syncNow() }
                    appDelegate.onFCMToken = { token in
                        Task { await app.cloud.updateFCMToken(token) }
                    }
                }
                .onOpenURL { app.handleDeepLink($0) }   // tweli:// scheme (widget, invite)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { app.handleUserActivity($0) }  // https invite link
                .environmentObject(app)
                .environmentObject(app.auth)
                .environmentObject(app.coupleSpaceService)
                .environmentObject(app.reminderService)
                .environmentObject(app.countdownService)
                .environmentObject(app.virtualDateService)
                .environmentObject(app.letterService)
                .environmentObject(app.moodService)
                .environmentObject(app.missingYouService)
                .environmentObject(app.notifications)
                .tint(.twAccent)
        }
    }
}

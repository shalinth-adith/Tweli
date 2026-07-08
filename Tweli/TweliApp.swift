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
    @StateObject private var app = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
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

//
//  MainTabView.swift
//  Tweli
//
//  The five-tab bar from the design: Home · Reminders · Dates · Moods · Letters.
//  Countdown / Missing You / Partner / Settings are pushed or presented from Home.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack { ReminderListView() }
                .tabItem { Label("Reminders", systemImage: "checklist") }

            NavigationStack { VirtualDatePlannerView() }
                .tabItem { Label("Dates", systemImage: "calendar") }

            NavigationStack { MoodSharingView() }
                .tabItem { Label("Moods", systemImage: "face.smiling") }

            NavigationStack { OpenWhenLettersView() }
                .tabItem { Label("Letters", systemImage: "envelope.fill") }
        }
    }
}

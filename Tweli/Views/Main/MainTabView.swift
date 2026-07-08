//
//  MainTabView.swift
//  Tweli
//
//  The five-tab bar from the design: Home · Reminders · Dates · Moods · Letters.
//  Countdown / Missing You / Partner / Settings are pushed or presented from Home.
//

import SwiftUI

struct MainTabView: View {
    @State private var selection = 0

    var body: some View {
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
    }
}

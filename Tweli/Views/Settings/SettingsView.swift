//
//  SettingsView.swift
//  Tweli
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var notifications: ReminderNotificationService

    var body: some View {
        Form {
            Section("Connection") {
                row("person.2.fill", "Partner", couple.partner?.displayName ?? "Not connected", .twAccent)
                row("icloud.fill", "iCloud sync", "On (mock)", .twAccent2)
            }

            Section("Notifications") {
                row("bell.fill", "Permission", notificationStatusText, notificationTint)
                if notifications.authorizationStatus != .authorized {
                    Button("Enable notifications") { app.requestNotificationPermission() }
                }
            }

            Section("Personalization") {
                Picker("Home layout", selection: $app.homeStyle) {
                    ForEach(HomeStyle.allCases) { Text($0.label).tag($0) }
                }
                row("app.badge.fill", "Reminder tone", "Default", .twAccent2)
            }

            Section("Widgets") {
                Label("Add a Tweli widget from your Home Screen", systemImage: "square.grid.2x2.fill")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Section("About") {
                row("heart.fill", "Tweli", "Version 1.0", .twAccent)
                Text("Built for the little things love should not forget.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Button("Disconnect partner space", role: .destructive) {
                    couple.disconnect()
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { notifications.refreshAuthorizationStatus() }
    }

    private var notificationStatusText: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "Allowed"
        case .denied: return "Denied"
        default: return "Not set"
        }
    }

    private var notificationTint: Color {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .twSuccess
        case .denied: return .twWarn
        default: return .twInkSecondary
        }
    }

    private func row(_ icon: String, _ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 26)
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

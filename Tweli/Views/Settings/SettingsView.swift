//
//  SettingsView.swift
//  Tweli
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var notifications: ReminderNotificationService

    @State private var editingProfile = false

    var body: some View {
        Form {
            Section {
                Button { editingProfile = true } label: { profileRow }
                    .buttonStyle(.plain)
            } header: {
                Text("You")
            } footer: {
                Text("Your partner sees your name, birthday and local time.")
            }

            Section("Connection") {
                row("person.2.fill", "Partner", couple.partner?.displayName ?? "Not connected", .twAccent)
                row("arrow.triangle.2.circlepath", "Sync", syncStatusText, .twAccent2)
            }

            Section("Notifications") {
                row("bell.fill", "Permission", notificationStatusText, notificationTint)
                if notifications.authorizationStatus != .authorized {
                    Button("Enable notifications") { app.requestNotificationPermission() }
                }
            }

            Section("Personalization") {
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
                Button("Leave shared space", role: .destructive) {
                    couple.disconnect()
                }
                Button("Sign out", role: .destructive) {
                    couple.disconnect()
                    auth.signOut()
                }
            } footer: {
                Text(auth.displayName.isEmpty ? "" : "Signed in as \(auth.displayName) via Apple.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { notifications.refreshAuthorizationStatus() }
        .sheet(isPresented: $editingProfile) {
            AboutYouView(isEditing: true)
                .environmentObject(app)
                .environmentObject(couple)
                .environmentObject(auth)
        }
    }

    /// Real sync state (replaces the retired "iCloud sync — On (mock)" row):
    /// Connected = space exists and Firebase reachable; Offline = space exists
    /// but no Firebase session (persistent cache serving data); Not connected =
    /// no shared space yet.
    private var syncStatusText: String {
        if couple.coupleSpace == nil { return "Not connected" }
        return app.cloud.accountAvailable ? "Connected" : "Offline"
    }

    /// The tappable "You" profile summary — photo, name, and birthday/city.
    private var profileRow: some View {
        HStack(spacing: 14) {
            ProfileAvatar(profile: couple.currentUser, isPartner: false, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(couple.currentUser.displayName.isEmpty ? "Add your details" : couple.currentUser.displayName)
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary)
                Text(profileSubtitle)
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var profileSubtitle: String {
        var parts: [String] = []
        if let bday = couple.currentUser.birthday {
            parts.append(bday.formatted(.dateTime.day().month(.abbreviated)))
        }
        if let city = couple.currentUser.city, !city.isEmpty { parts.append(city) }
        return parts.isEmpty ? "Tap to add photo, birthday & city" : parts.joined(separator: " · ")
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

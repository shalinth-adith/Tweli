//
//  NotificationSettingsView.swift
//  Tweli
//
//  Comp V3 — "Notification settings: per-type switches, and quiet hours for
//  both of you."
//
//  Every switch here is stored on the SPACE document, not on the device,
//  because the Cloud Function has to read it before it sends. A device-only
//  switch would hide the banner while the push still arrived.
//
//  The comp's "Hold yours for her night" row is not drawn: holding a send until
//  the recipient wakes needs a server-side queue that doesn't exist. What the
//  backend actually does — deliver silently during their night — is already
//  explained on the Quiet hours screen, so promising a queue here would
//  contradict it.
//

import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var notifications: ReminderNotificationService

    @State private var prefs = NotificationPreferences.default
    @State private var loaded = false

    private var partnerName: String { couple.partner?.displayName ?? "your partner" }
    private var hasPartner: Bool { couple.partner != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if notifications.authorizationStatus != .authorized { permissionBanner }

                if hasPartner {
                    sectionLabel("From \(partnerName)")
                    group {
                        toggleRow("Moods", "The moment they update", $prefs.moods)
                        divider
                        toggleRow("Letters", "When one arrives — never spoiled", $prefs.letters)
                        divider
                        toggleRow("Their morning", "A nudge when they wake up", $prefs.partnerMorning)
                    }
                }

                sectionLabel("From Tweli")
                group {
                    toggleRow("Reminders", "Gentle nudges, never alarms", $prefs.reminders)
                    divider
                    toggleRow("Countdown milestones", "21 days → 14 → 7 → tomorrow",
                              $prefs.countdownMilestones)
                }

                sectionLabel("Quiet hours")
                group {
                    hourRow("From", $prefs.quietStart)
                    divider
                    hourRow("Until", $prefs.quietEnd)
                }
                Text("Nothing buzzes on your phone between these hours. Anything that arrives waits quietly on the lock screen.")
                    .font(.system(size: 12))
                    .lineSpacing(3)
                    .foregroundStyle(Color.twInkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.top, 10)

                if let live = partnerClockLine {
                    Text(live)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.twAccent2Ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                        .padding(.top, 14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Load once, then let every change write straight through.
            prefs = await app.cloud.loadNotificationPreferences()
            loaded = true
            notifications.refreshAuthorizationStatus()
        }
        .onChange(of: prefs) { _, new in
            guard loaded else { return }        // don't echo the initial load back
            Task { await app.cloud.saveNotificationPreferences(new) }
        }
    }

    // MARK: - Permission

    /// Switches are meaningless while iOS itself is blocking delivery, so say so
    /// before the user toggles things that can't take effect.
    private var permissionBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.twWarn)
            VStack(alignment: .leading, spacing: 1) {
                Text("Notifications are off for Tweli")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Color.twInk)
                Text("Turn them on in iOS Settings for anything below to reach you.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.twInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.twWarn.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.twWarn.opacity(0.22), lineWidth: 1)
        }
        .padding(.top, 12)
    }

    // MARK: - Rows

    private func toggleRow(_ title: String, _ subtitle: String,
                           _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15.5))
                    .foregroundStyle(Color.twInk)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.twInkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(Color.twSuccess)
        }
        .padding(.vertical, 13)
    }

    /// Whole hours only. A quiet window is a rough boundary around sleep, and
    /// minute precision invites fiddling for no benefit.
    private func hourRow(_ label: String, _ binding: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15.5))
                .foregroundStyle(Color.twInk)
            Spacer()
            Picker("", selection: binding) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(Self.hourLabel(hour)).tag(hour)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Color.twAccentInk)
        }
        .padding(.vertical, 12)
    }

    private static func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Comp V3's live line. Only shown when we genuinely know their zone.
    private var partnerClockLine: String? {
        guard hasPartner, let zone = app.partnerTimeZone else { return nil }
        var fmt = Date.FormatStyle.dateTime.hour().minute()
        fmt.timeZone = zone
        var cal = Calendar.current
        cal.timeZone = zone
        let awake = !prefs.isQuiet(hour: cal.component(.hour, from: Date()))
        return "Right now it's \(Date().formatted(fmt)) for \(partnerName) — "
             + (awake ? "they're awake." : "they're likely asleep.")
    }

    // MARK: - Chrome

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .tweliEyebrow()
            .tracking(0.6)
            .padding(.horizontal, 4)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .tweliCard(radius: 18)
    }

    private var divider: some View {
        Rectangle().fill(Color.twSeparator).frame(height: 1)
    }
}

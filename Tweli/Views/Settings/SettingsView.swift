//
//  SettingsView.swift
//  Tweli
//
//  Comp L9 / N9 / B7 — "Our space". Not a settings Form: a hero card with both
//  avatars joined by the thread and the three numbers that describe the
//  relationship, then quiet grouped rows, then one red exit at the bottom.
//
//  Every number here is real or absent. With no partner, no shared location and
//  no meet date, the hero shows what it honestly knows and nothing more.
//

import SwiftUI
import UserNotifications
import AuthenticationServices

struct SettingsView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var notifications: ReminderNotificationService
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var countdowns: CountdownService
    @EnvironmentObject private var theme: ThemeService

    @Environment(\.dismiss) private var dismiss

    @State private var editingProfile = false
    @State private var confirmLeave = false
    @State private var showQuietHours = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroCard

                sectionLabel("You")
                group {
                    Button { editingProfile = true } label: { profileRow }
                        .buttonStyle(.plain)
                }

                sectionLabel("Space")
                group {
                    valueRow("person.2.fill", "Partner",
                             couple.partner?.displayName ?? "Not connected", tint: .twAccent)
                    divider
                    valueRow("arrow.triangle.2.circlepath", "Sync", syncStatusText, tint: .twAccent2)
                    if let code = app.cloud.activePairCode {
                        divider
                        valueRow("number", "Invite code",
                                 FirebaseService.formatPairCode(code),
                                 tint: .twAccent2, monospaced: true)
                    }
                }

                sectionLabel("App")
                group {
                    notificationsRow
                    divider
                    Button { showQuietHours = true } label: {
                        chevronRow("moon.zzz.fill", "Quiet hours", tint: .twAccent2)
                    }
                    .buttonStyle(.plain)
                    divider
                    themeRow
                    divider
                    widgetRow
                }

                sectionLabel("About")
                group {
                    valueRow("heart.fill", "Tweli", appVersion, tint: .twAccent)
                }

                // The one red thing on the screen.
                group {
                    Button { confirmLeave = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.twDanger)
                                .frame(width: 24)
                            Text("Leave this space")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.twDanger)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 20)

                Text("Leaving keeps your letters safe for 30 days.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.twInkQuaternary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 14)

                // Deletion is not "leave, but more" — it is permanent and it is
                // separate, so it gets its own block and its own warning.
                group {
                    Button { confirmDelete = true } label: {
                        HStack(spacing: 12) {
                            if deleting {
                                ProgressView().frame(width: 24)
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.twDanger)
                                    .frame(width: 24)
                            }
                            Text(deleting ? "Deleting…" : "Delete my account")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.twDanger)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(deleting)
                }
                .padding(.top, 26)

                Text("Permanent. Everything you wrote is erased from our servers and can't be recovered.")
                    .font(.system(size: 12))
                    .lineSpacing(2)
                    .foregroundStyle(Color.twInkQuaternary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.top, 14)

                if let deleteError {
                    Text(deleteError)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.twDangerInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                        .padding(.top, 10)
                }

                Button("Sign out") { app.signOut() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.twInkTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.twBackground.ignoresSafeArea())
        .navigationTitle("Our space")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { notifications.refreshAuthorizationStatus() }
        .sheet(isPresented: $editingProfile) {
            AboutYouView(isEditing: true)
                .environmentObject(app)
                .environmentObject(couple)
                .environmentObject(auth)
        }
        .sheet(isPresented: $showQuietHours) { QuietHoursView() }
        .confirmationDialog("Leave this space?",
                            isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave this space", role: .destructive) {
                app.leaveSpace()
                dismiss()
            }
            Button("Stay", role: .cancel) { }
        } message: {
            Text("Your letters are kept safe for 30 days. You can invite your partner back anytime.")
        }
        .confirmationDialog("Delete your account permanently?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) { deleteAccount() }
            Button("Keep my account", role: .cancel) { }
        } message: {
            Text(deleteWarning)
        }
    }

    /// Says exactly what goes and what survives, because the answer depends on
    /// whether anyone else is still in the space.
    private var deleteWarning: String {
        let mine = "Your moods, letters, reminders, dates and location will be permanently erased from our servers. This can't be undone."
        guard let partner = couple.partner?.displayName, !partner.isEmpty else {
            return mine + " Your shared space will be deleted too."
        }
        return mine + " \(partner) keeps what they wrote, and will be told you've left."
    }

    private func deleteAccount() {
        deleteError = nil
        deleting = true
        Task {
            do {
                try await app.deleteAccountPermanently()
                // RootView drops back to the entry screen on its own once the
                // signed-in flag clears; nothing to dismiss here.
            } catch is CancellationError {
                deleteError = nil
            } catch {
                // A cancelled Apple sheet is a decision, not a failure.
                let cancelled = (error as? ASAuthorizationError)?.code == .canceled
                deleteError = cancelled ? nil : error.localizedDescription
            }
            deleting = false
        }
    }

    // MARK: - Hero (two avatars, one thread, three numbers)

    private var heroCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                avatar(couple.currentUser.initials, isPartner: false)
                thread
                avatar(couple.partner?.initials ?? "?", isPartner: true)
            }

            Text(pairTitle)
                .font(.system(size: 19, weight: .heavy))
                .tracking(-0.3)
                .foregroundStyle(Color.twInk)
                .multilineTextAlignment(.center)
                .padding(.top, 14)

            if let cities = citiesLine {
                Text(cities)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.twInkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 3)
            }

            if !stats.isEmpty {
                HStack(alignment: .top, spacing: 22) {
                    ForEach(stats, id: \.label) { stat in
                        VStack(spacing: 1) {
                            Text(stat.value)
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(stat.tint)
                            Text(stat.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.twInkTertiary)
                        }
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background {
            let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
            shape.fill(LinearGradient(colors: [.twElevated2, .twElevatedWarm],
                                      startPoint: .top, endPoint: .bottom))
                .overlay { shape.strokeBorder(Color.twAccent2.opacity(0.3), lineWidth: 1) }
        }
        .padding(.top, 10)
    }

    private func avatar(_ initials: String, isPartner: Bool) -> some View {
        Circle()
            .fill(isPartner ? TweliGradient.partnerAvatar : TweliGradient.meAvatar)
            .frame(width: 54, height: 54)
            .overlay {
                Text(initials.isEmpty ? "·" : initials)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: (isPartner ? Color.twAccent2 : Color.twAccent).opacity(0.45), radius: 11)
    }

    /// The mark itself: the two of you, joined.
    private var thread: some View {
        Rectangle()
            .fill(TweliGradient.thread)
            .frame(width: 46, height: 2)
    }

    private var pairTitle: String {
        let me = couple.currentUser.displayName
        guard let partner = couple.partner?.displayName, !partner.isEmpty else {
            return me.isEmpty ? "Your space" : me
        }
        return "\(me) ♥ \(partner)"
    }

    /// Only rendered when both cities are actually known.
    private var citiesLine: String? {
        let mine = location.myLocation?.cityLabel
        let theirs = location.partnerLocation?.cityLabel
        let known = [mine, theirs].compactMap { $0 }
        return known.isEmpty ? nil : known.joined(separator: " · ")
    }

    private struct Stat { let value: String; let label: String; let tint: Color }

    /// Three numbers — but only the ones we genuinely have.
    private var stats: [Stat] {
        var out: [Stat] = []
        if let distance = location.distanceApartLabel {
            // Keep the formatter's own unit — it yields miles in US locales, so
            // splitting " km" off and labelling the tile "km apart" printed the
            // wrong unit and left the number unstripped.
            out.append(Stat(value: distance, label: "apart", tint: .twInfo))
        }
        if let days = daysTogether {
            out.append(Stat(value: "\(days)", label: "days together", tint: .twAccentInk))
        }
        if let go = reunionDays {
            out.append(Stat(value: "\(go)", label: "days to go", tint: .twWarnInk))
        }
        return out
    }

    private var daysTogether: Int? {
        guard let start = couple.coupleSpace?.createdAt else { return nil }
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: start),
                                         to: cal.startOfDay(for: Date())).day ?? 0)
    }

    private var reunionDays: Int? {
        (countdowns.countdowns.first { $0.category == .meeting } ?? countdowns.pinned)?.daysRemaining
    }

    // MARK: - Rows

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .tweliEyebrow()
            .tracking(0.6)
            .padding(.horizontal, 2)
            .padding(.top, 22)
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

    private var profileRow: some View {
        HStack(spacing: 14) {
            ProfileAvatar(profile: couple.currentUser, isPartner: false, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(couple.currentUser.displayName.isEmpty ? "Add your details"
                                                            : couple.currentUser.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.twInk)
                Text(profileSubtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.twInkTertiary)
                    .lineLimit(1)
            }
            Spacer()
            chevron
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var notificationsRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.twAccent)
                .frame(width: 24)
            Text("Notifications")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.twInk)
            Spacer()
            if notifications.authorizationStatus == .authorized {
                Text("On")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.twSuccess)
            } else {
                Button("Turn on") { app.requestNotificationPermission() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.twAccentInk)
            }
        }
        .padding(.vertical, 14)
    }

    /// Comp L9 reads "Light", N9 reads "Dark", B7 reads "Auto" — tapping cycles.
    private var themeRow: some View {
        Button { withAnimation(.easeInOut(duration: 0.25)) { theme.advance() } } label: {
            HStack(spacing: 12) {
                Image(systemName: theme.theme.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.twAccent2)
                    .frame(width: 24)
                Text("Theme")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.twInk)
                Spacer()
                Text(theme.theme.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.twAccent2)
                    .contentTransition(.opacity)
                chevron
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var widgetRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.twAccent2)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("Home-screen widget")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.twInk)
                Text("Touch and hold your Home Screen, then add Tweli.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.twInkTertiary)
            }
            Spacer()
        }
        .padding(.vertical, 14)
    }

    private func valueRow(_ icon: String, _ label: String, _ value: String,
                          tint: Color, monospaced: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.twInk)
            Spacer()
            Text(value)
                .font(monospaced ? .system(size: 14, weight: .semibold, design: .monospaced)
                                 : .system(size: 14))
                .foregroundStyle(Color.twInkTertiary)
        }
        .padding(.vertical, 14)
    }

    private func chevronRow(_ icon: String, _ label: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.twInk)
            Spacer()
            chevron
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.twInkQuaternary)
    }

    // MARK: - Values

    private var syncStatusText: String {
        if couple.coupleSpace == nil { return "Not connected" }
        return app.cloud.accountAvailable ? "Connected" : "Offline"
    }

    private var profileSubtitle: String {
        var parts: [String] = []
        if let bday = couple.currentUser.birthday {
            parts.append(bday.formatted(.dateTime.day().month(.abbreviated)))
        }
        if let city = couple.currentUser.city, !city.isEmpty { parts.append(city) }
        return parts.isEmpty ? "Tap to add photo, birthday & city" : parts.joined(separator: " · ")
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(v)"
    }
}

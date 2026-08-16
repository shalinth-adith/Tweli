//
//  WelcomeBackView.swift
//  Tweli
//
//  Comps K3 / KL3 — "you're still with <partner>".
//
//  The point of this screen is proof. A reinstall feels like loss whether or not
//  anything was lost, and "everything is fine" is a claim; four counted rows are
//  evidence. Every figure is read out of the local store by
//  `RestoreCounting.summary` AFTER the listeners have delivered, so what this
//  screen prints is exactly what the next screen shows.
//
//  When the space is real but empty, the stat rows are dropped entirely rather
//  than printed as four zeroes — a pair that hadn't written anything yet should
//  not be shown what looks like a failed restore.
//

import SwiftUI

struct WelcomeBackView: View {
    let summary: RestoreSummary

    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @Environment(\.colorScheme) private var scheme
    @State private var appear = false
    @State private var showLeave = false

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                avatars
                    .padding(.top, 8)

                Text("You're still\nwith \(summary.partnerName)")
                    .font(.system(size: 32, weight: .heavy))
                    .tracking(-0.8)
                    .lineSpacing(1)
                    .foregroundStyle(Color.twInk)
                    .multilineTextAlignment(.center)
                    // The name is whatever the partner typed. Without these a
                    // long one breaks mid-word across three lines and pushes the
                    // stat rows off the screen — the exact rows that make this
                    // screen worth showing.
                    .lineLimit(3)
                    .minimumScaleFactor(0.62)
                    .padding(.top, 26)

                Text(subtitle)
                    .font(.system(size: 14.5))
                    .lineSpacing(3)
                    .foregroundStyle(Color.twInkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                if !summary.isEmpty {
                    stats.padding(.top, 28)
                }

                Spacer(minLength: 0)

                actions.padding(.bottom, 26)
            }
            .padding(.horizontal, 30)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { appear = true }
        }
    }

    /// "Paired 214 days" only when the space document carries a `createdAt`.
    /// Spaces made before that field existed get the shorter sentence instead of
    /// an invented duration.
    private var subtitle: String {
        let tail = "The reinstall didn't cost you anything on this side."
        guard let days = summary.pairedDays else { return tail }
        return "Paired \(days) \(days == 1 ? "day" : "days"). \(tail)"
    }

    // MARK: - Avatars

    private var avatars: some View {
        HStack(spacing: -14) {
            ProfileAvatar(profile: couple.currentUser, size: 64)
                .zIndex(1)
            ProfileAvatar(profile: couple.partner, isPartner: true, size: 64)
        }
        .scaleEffect(appear ? 1 : 0.8)
    }

    // MARK: - What came back

    private var stats: some View {
        VStack(spacing: 9) {
            if summary.reminders > 0 {
                statRow(icon: "checkmark.square", tint: Color.twSuccess,
                        label: "\(summary.reminders) \(summary.reminders == 1 ? "reminder" : "reminders")",
                        trailing: summary.openReminders > 0 ? "\(summary.openReminders) open" : "all done")
            }
            if summary.letters > 0 {
                statRow(icon: "envelope", tint: Color.twWarnInk,
                        label: "\(summary.letters) \(summary.letters == 1 ? "letter" : "letters")",
                        trailing: summary.sealedLetters > 0
                                  ? "\(summary.sealedLetters) sealed" : nil)
            }
            if let mood = summary.partnerMood {
                statRow(icon: "heart", tint: Color.twAccent,
                        label: "Their mood", trailing: mood)
            }
            if summary.plannedDates > 0 {
                statRow(icon: "calendar", tint: Color.twAccent2,
                        label: "\(summary.plannedDates) planned \(summary.plannedDates == 1 ? "date" : "dates")",
                        trailing: summary.nextDate.map {
                            $0.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        })
            }
        }
    }

    private func statRow(icon: String, tint: Color, label: String, trailing: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)

            Text(label)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(Color.twInk)

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.twInkTertiary)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(Color.twElevated.opacity(0.8),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.twHairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 14) {
            BrandCTA(title: "Open Tweli", showsArrow: false) { app.finishRejoined() }

            // The comp's quiet exit. It opens the ordinary W2 leave flow rather
            // than a shortcut: leaving is real and destructive, and it should
            // look identical wherever it is reached from — same tally, same
            // keepsake export, same confirmation.
            Button { showLeave = true } label: {
                (Text("Not your pair anymore? ")
                    .foregroundStyle(Color.twInkTertiary)
                 + Text("Leave the thread")
                    .foregroundStyle(Color.twAccent2))
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showLeave) {
            NavigationStack { BeforeYouGoView() }
        }
    }
}

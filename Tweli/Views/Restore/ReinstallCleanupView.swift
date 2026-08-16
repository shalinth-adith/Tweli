//
//  ReinstallCleanupView.swift
//  Tweli
//
//  Comps K4 / KL4 — "your phone forgot these, not us".
//
//  The two things deleting the app genuinely takes away are the Home Screen
//  widget and the notification permission. Everything else came back with the
//  account, which is why this screen is short and why it is the last one.
//
//  Both rows are checked against the system before the screen is raised
//  (`AppViewModel.refreshCleanupState()`), and a row only appears when its thing
//  is actually undone. If neither is, the screen never shows at all — telling
//  somebody their widget is missing while it sits on their Home Screen is the
//  same class of untruth as a fabricated placeholder, just harder to spot.
//

import SwiftUI
import UIKit

struct ReinstallCleanupView: View {
    @EnvironmentObject private var app: AppViewModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var appear = false
    @State private var showWidgetHelp = false
    @State private var requesting = false

    private var cleanup: ReinstallCleanup { app.cleanup }

    var body: some View {
        ZStack {
            TweliGradient.sky(scheme).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                Text(cleanup.widgetMissing && cleanup.notificationsOff
                     ? "Two things left" : "One thing left")
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(Color.twAccentInk)

                Text("Your phone forgot\nthese, not us")
                    .font(.system(size: 31, weight: .heavy))
                    .tracking(-0.7)
                    .lineSpacing(1)
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 11)

                Text(intro)
                    .font(.system(size: 14.5))
                    .lineSpacing(3)
                    .foregroundStyle(Color.twInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 11)

                VStack(spacing: 12) {
                    if cleanup.widgetMissing { widgetCard }
                    if cleanup.notificationsOff { notificationCard }
                }
                .padding(.top, 26)

                Spacer(minLength: 0)

                Button("Later") { app.endRestore() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.twInkTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 30)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 10)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appear = true }
        }
        .sheet(isPresented: $showWidgetHelp) { WidgetHelpSheet() }
        // Coming back from Settings is the ONLY signal that a permission
        // changed — iOS doesn't notify the app. Without this re-check the user
        // grants notifications, returns, and the screen still insists they are off.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await app.refreshCleanupState()
                if app.cleanup.isEmpty { app.endRestore() }
            }
        }
    }

    /// Names only what is actually true. The generic version of this paragraph
    /// listed both losses regardless, which was wrong the moment only one applied.
    private var intro: String {
        switch (cleanup.widgetMissing, cleanup.notificationsOff) {
        case (true, true):
            "Deleting the app removed the widget from your home screen and took back notification permission. Everything else is already restored."
        case (true, false):
            "Deleting the app removed the widget from your home screen. Everything else is already restored."
        case (false, true):
            "Deleting the app took back notification permission. Everything else is already restored."
        case (false, false):
            "Everything is already restored."
        }
    }

    // MARK: - Rows

    private var widgetCard: some View {
        cleanupCard(
            icon: "square.grid.2x2",
            tint: Color.twAccent2,
            title: "Widget removed",
            detail: "Their mood won't show on your home screen until you place it again.",
            action: "Show me how"
        ) { showWidgetHelp = true }
    }

    private var notificationCard: some View {
        cleanupCard(
            icon: "bell",
            tint: Color.twWarnInk,
            title: "Notifications off",
            detail: "Their reminders and letters will arrive silently until you allow them.",
            action: deniedForGood ? "Open Settings" : "Turn on notifications",
            loading: requesting
        ) {
            // Once iOS has recorded a denial it will never show the prompt
            // again, so a button labelled "Turn on notifications" that calls
            // requestAuthorization() would silently do nothing. Past that point
            // the only honest action is to open Settings.
            if deniedForGood {
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            } else {
                requesting = true
                Task {
                    await app.requestNotificationsFromCleanup()
                    requesting = false
                }
            }
        }
    }

    private var deniedForGood: Bool { app.notifications.authorizationStatus == .denied }

    private func cleanupCard(icon: String, tint: Color, title: String, detail: String,
                             action: String, loading: Bool = false,
                             perform: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(Color.twInk)
                    Text(detail)
                        .font(.system(size: 13))
                        .lineSpacing(2)
                        .foregroundStyle(Color.twInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: perform) {
                HStack(spacing: 7) {
                    if loading { ProgressView().controlSize(.small) }
                    Text(action)
                        .font(.system(size: 14.5, weight: .bold))
                }
                .foregroundStyle(Color.twAccent2)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.twAccent2.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(loading)
        }
        .padding(16)
        .background(Color.twElevated.opacity(0.85),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.twHairline, lineWidth: 1)
        }
    }
}

// MARK: - "Show me how"

/// There is no API to add a widget for the user — iOS reserves that gesture — so
/// the honest thing is to describe it accurately and get out of the way.
private struct WidgetHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let steps = [
        "Touch and hold an empty part of your Home Screen until the icons jiggle.",
        "Tap the + button in the top corner.",
        "Search for Tweli, then choose a size.",
        "Tap Add Widget, then Done.",
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Put the widget back")
                    .font(.system(size: 25, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 6)

                Text("Four taps, and their mood is on your Home Screen again.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.twInkSecondary)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(Color.twAccent2)
                                .frame(width: 26, height: 26)
                                .background(Color.twAccent2.opacity(0.14), in: Circle())
                            Text(step)
                                .font(.system(size: 14.5))
                                .lineSpacing(2)
                                .foregroundStyle(Color.twInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 26)

                Spacer()
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.twBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

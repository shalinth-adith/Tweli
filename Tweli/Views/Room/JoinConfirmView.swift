//
//  JoinConfirmView.swift
//  Tweli
//
//  Shown when the partner opens an invite link or enters a code. Confirms who
//  invited them and which space, then — on Join — shows the "Tying your thread…"
//  connecting state (design 19g/h styling) while the atomic join runs.
//

import SwiftUI

struct JoinConfirmView: View {
    @EnvironmentObject private var app: AppViewModel
    let invite: PendingInvite

    @State private var joining = false
    @State private var joinFailed = false
    @State private var accepted = false
    @State private var detent: PresentationDetent = .large
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if joining {
                ConnectingView(spaceTitle: invite.spaceTitle)
            } else {
                confirmContent
            }
        }
        // J6 is a full-height moment, not a half card — the comp gives it the
        // whole screen so the tick and the thread have room to land.
        .presentationDetents([.large], selection: $detent)
        .interactiveDismissDisabled(joining)
    }

    // MARK: - Confirm

    /// Comp J6 "Code accepted". The comp's whole idea is that this beat is a
    /// payoff, not a form: the code is already known to be good, so the screen
    /// names the person rather than asking the user to verify a space title.
    private var confirmContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            // Green tick, then the thread draws between the two of you.
            ZStack {
                Circle()
                    .fill(Color.twSuccess.opacity(0.16))
                    .frame(width: 84, height: 84)
                    .scaleEffect(accepted ? 1 : 0.6)
                    .opacity(accepted ? 1 : 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.twSuccess)
                    .scaleEffect(accepted ? 1 : 0.4)
                    .opacity(accepted ? 1 : 0)
            }

            Text("Code accepted")
                .font(.system(size: 12, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.twSuccess)
                .padding(.top, 20)

            Text("That’s \(invite.inviterName).")
                .font(.system(size: 27, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Color.twInk)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Text("Joining \(possessive(invite.inviterName)) space now.")
                .font(.system(size: 14.5))
                .foregroundStyle(Color.twInkSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            HStack(spacing: 0) {
                AvatarBubble(initial: invite.inviterName, isPartner: true, size: 54)
                Rectangle().fill(.clear).frame(width: 74, height: 44)
                    .overlay(
                        ThreadConnect()
                            .trim(from: 0, to: accepted ? 1 : 0)
                            .stroke(TweliGradient.thread,
                                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    )
                    .padding(.horizontal, -4)
                ProfileAvatar(profile: app.currentUser, isPartner: false, size: 54)
            }
            .padding(.top, 26)

            Spacer(minLength: 8)

            VStack(spacing: 12) {
                if joinFailed {
                    Label(app.joinError ?? "Couldn't join right now. Check your connection and try again.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Brand.pink)
                        .multilineTextAlignment(.center)
                }

                BrandCTA(title: joinFailed ? "Try again" : "Enter Tweli", showsArrow: false) {
                    join()
                }

                Button("Not now") { app.cancelPendingJoin() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.twInkSecondary)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 20)
        .onAppear {
            guard !reduceMotion else { accepted = true; return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { accepted = true }
        }
    }

    /// "Anaya" → "Anaya's", "Chris" → "Chris'". Names are user-supplied, so the
    /// trailing-s case is worth getting right rather than always appending "'s".
    private func possessive(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "their" }
        return trimmed.lowercased().hasSuffix("s") ? "\(trimmed)’" : "\(trimmed)’s"
    }

    private func join() {
        joinFailed = false
        withAnimation { joining = true }
        Task {
            let ok = await app.confirmPendingJoin()
            if !ok {
                // Recover to the confirm card so the user can retry or dismiss.
                withAnimation { joining = false }
                joinFailed = true
            }
            // On success the sheet dismisses itself (pendingInvite → nil) and the
            // app lands on the connected home.
        }
    }
}

/// The partner-side "Tying your thread…" connecting screen shown while the join
/// transaction runs. Mirrors 19g/h without the owner's waiting checklist.
private struct ConnectingView: View {
    let spaceTitle: String
    @Environment(\.colorScheme) private var scheme
    @State private var draw = false
    @State private var appear = false

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle()
                        .fill((scheme == .dark ? Brand.pinkLift : Brand.pink).opacity(0.14))
                        .frame(width: 170, height: 170)
                    HStack(spacing: 0) {
                        AvatarBubble(initial: "", isPartner: true, size: 66)
                        Rectangle().fill(.clear).frame(width: 96, height: 56)
                            .overlay(
                                ThreadConnect()
                                    .trim(from: 0, to: draw ? 1 : 0)
                                    .stroke(LinearGradient(colors: [Brand.indigo, Brand.pink], startPoint: .leading, endPoint: .trailing),
                                            style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                            )
                            .padding(.horizontal, -6)
                        AvatarBubble(initial: "", isPartner: false, size: 66)
                    }
                }
                Text("Tying your thread…")
                    .font(.system(size: 26, weight: .heavy)).kerning(-0.6)
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 26)
                Text("Joining \(spaceTitle)")
                    .font(.system(size: 14.5)).foregroundStyle(Color.twInkSecondary)
                    .padding(.top, 8)
                ProgressView()
                    .padding(.top, 26)
                Spacer()
            }
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { draw = true }
        }
    }
}

private struct ThreadConnect: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.07, y: h * 0.68))
        p.addCurve(to: CGPoint(x: w * 0.93, y: h * 0.32),
                   control1: CGPoint(x: w * 0.36, y: h * 0.18),
                   control2: CGPoint(x: w * 0.64, y: h * 0.82))
        return p
    }
}

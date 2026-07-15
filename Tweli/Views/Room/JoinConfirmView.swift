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
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        Group {
            if joining {
                ConnectingView(spaceTitle: invite.spaceTitle)
            } else {
                confirmContent
            }
        }
        .presentationDetents(joining ? [.large] : [.medium, .large], selection: $detent)
        .interactiveDismissDisabled(joining)
    }

    // MARK: - Confirm

    private var confirmContent: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            HStack(spacing: 0) {
                AvatarBubble(initial: invite.inviterName, isPartner: true, size: 58)
                Image(systemName: "ellipsis")
                    .font(.title3).foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                ProfileAvatar(profile: app.currentUser, isPartner: false, size: 58)
            }

            VStack(spacing: 8) {
                Text("Join “\(invite.spaceTitle)”?")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text("\(invite.inviterName) invited you to your shared space 💞")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)

            Text("You'll share reminders, moods, countdowns and letters — just the two of you.")
                .font(.footnote).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer(minLength: 8)

            VStack(spacing: 12) {
                if joinFailed {
                    Label(app.joinError ?? "Couldn't join right now. Check your connection and try again.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Brand.pink)
                        .multilineTextAlignment(.center)
                }

                BrandCTA(title: joinFailed ? "Try again" : "Join space", showsArrow: false) {
                    join()
                }

                Button("Not now") { app.cancelPendingJoin() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 20)
    }

    private func join() {
        joinFailed = false
        withAnimation { joining = true; detent = .large }
        Task {
            let ok = await app.confirmPendingJoin()
            if !ok {
                // Recover to the confirm card so the user can retry or dismiss.
                withAnimation { joining = false; detent = .medium }
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
                    .foregroundStyle(.primary)
                    .padding(.top, 26)
                Text("Joining \(spaceTitle)")
                    .font(.system(size: 14.5)).foregroundStyle(.secondary)
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

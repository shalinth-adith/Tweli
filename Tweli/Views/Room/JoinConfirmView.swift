//
//  JoinConfirmView.swift
//  Tweli
//
//  Shown when the partner opens an invite link. Confirms who invited them and
//  which space before actually accepting the CloudKit share.
//

import SwiftUI

struct JoinConfirmView: View {
    @EnvironmentObject private var app: AppViewModel
    let invite: PendingInvite

    @State private var joining = false
    @State private var joinFailed = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            // Pairing motif — two dots drawn together into one space.
            HStack(spacing: 0) {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.42, blue: 0.54), .twAccent],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                    .overlay(Image(systemName: "heart.fill").foregroundStyle(.white))
                Image(systemName: "ellipsis")
                    .font(.title3).foregroundStyle(Color.twInkTertiary)
                    .padding(.horizontal, 10)
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 0.48, green: 0.47, blue: 1), .twAccent2],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                    .overlay(Text(app.currentUser.initials).font(.title3.weight(.semibold)).foregroundStyle(.white))
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

            VStack(spacing: 10) {
                if joinFailed {
                    Label("Couldn't join right now. Check your connection and try again.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Color.twWarn)
                        .multilineTextAlignment(.center)
                }

                PrimaryButton(title: joining ? "Joining…" : (joinFailed ? "Try again" : "Join space"),
                              systemImage: "heart.fill") {
                    joining = true
                    joinFailed = false
                    Task {
                        let ok = await app.confirmPendingJoin()
                        if !ok {
                            // Recover: re-enable the buttons so the user can retry
                            // or dismiss instead of a forever-disabled "Joining…".
                            joining = false
                            joinFailed = true
                        }
                    }
                }
                .disabled(joining)

                Button("Not now") { app.cancelPendingJoin() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .disabled(joining)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 20)
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(joining)
    }
}

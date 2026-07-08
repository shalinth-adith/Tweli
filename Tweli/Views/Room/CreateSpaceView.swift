//
//  CreateSpaceView.swift
//  Tweli
//
//  Design 11a — name the shared space and invite the partner via a link.
//

import SwiftUI
import UIKit

struct CreateSpaceView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @Environment(\.dismiss) private var dismiss

    @State private var spaceName = ""
    @State private var inviteLink = ""
    @State private var copied = false

    private var partnerName: String { app.partner?.displayName ?? "your partner" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    pairingHero
                    titleBlock
                    nameField
                    inviteCard
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 20)
            }
            continueBar
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Create space")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if inviteLink.isEmpty { inviteLink = couple.makeDraftInviteLink() } }
    }

    // MARK: - Pairing hero (you --- invite)

    private var pairingHero: some View {
        HStack(spacing: 0) {
            avatar(app.currentUser.initials, gradient: [Color(red: 0.48, green: 0.47, blue: 1), .twAccent2], label: "You")
            Image(systemName: "ellipsis")
                .font(.title2).foregroundStyle(Color.twInkTertiary)
                .padding(.horizontal, 8).padding(.bottom, 18)
            VStack(spacing: 8) {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4]))
                    .foregroundStyle(Color.twInkTertiary)
                    .frame(width: 60, height: 60)
                    .overlay(Image(systemName: "plus").font(.title3).foregroundStyle(Color.twInkTertiary))
                Text("Invite").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 14)
    }

    private func avatar(_ initials: String, gradient: [Color], label: String) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 60, height: 60)
                .overlay(Text(initials).font(.title3.weight(.semibold)).foregroundStyle(.white))
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("Create your space").font(.system(size: 26, weight: .heavy)).foregroundStyle(.primary)
            Text("One shared world for the two of you.\nName it, then invite your person.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Space name").tweliEyebrow()
            HStack(spacing: 10) {
                Image(systemName: "heart.fill").foregroundStyle(Color.twAccent)
                TextField("Shalinth & Anaya", text: $spaceName)
                    .font(.body)
            }
            .padding(15)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Invite your partner").tweliEyebrow()
            VStack(alignment: .leading, spacing: 12) {
                Text("Share this link so they can join your space.")
                    .font(.footnote).foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Text(inviteLink)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        UIPasteboard.general.string = inviteLink
                        withAnimation { copied = true }
                        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); withAnimation { copied = false } }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(Color.twAccent)
                            .background(Color.twAccentSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(13)
                .background(Color(UIColor.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                ShareLink(item: URL(string: inviteLink) ?? URL(string: "https://tweli.app")!,
                          message: Text("Join our space on Tweli 💞")) {
                    Label("Share invite", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(14)
                        .foregroundStyle(.white).background(Color.twAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var continueBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Color.twWarn).frame(width: 8, height: 8)
                Text("You can share the invite anytime from Settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            PrimaryButton(title: "Create & continue", systemImage: "heart.fill") {
                couple.createSpace(title: spaceName)
            }
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 8)
        .background(.bar)
    }
}

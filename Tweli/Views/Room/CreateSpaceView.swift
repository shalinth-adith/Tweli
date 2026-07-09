//
//  CreateSpaceView.swift
//  Tweli
//
//  Design 11a — name the shared space and invite the partner via a link.
//

import SwiftUI
import UIKit
import CloudKit

struct CreateSpaceView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @Environment(\.dismiss) private var dismiss

    @State private var spaceName = ""
    @State private var inviteLink = ""          // the REAL CKShare URL, once created
    @State private var copied = false
    @State private var cloudShare: CKShare?
    @State private var showCloudShare = false
    @State private var showLinkShare = false
    @State private var preparingShare = false
    @State private var shareError: String?

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
        .sheet(isPresented: $showCloudShare) {
            if let cloudShare {
                CloudSharingSheet(share: cloudShare, container: app.cloud.container)
            }
        }
        .sheet(isPresented: $showLinkShare) { ActivityView(items: [inviteLink]) }
    }

    /// Creates the real CloudKit share and captures its public URL — a proper
    /// https://www.icloud.com/share/… link that opens Tweli when tapped. Needs an
    /// iCloud account (real device); on the simulator this reports why it can't.
    private func createInviteLink() async {
        preparingShare = true
        shareError = nil
        defer { preparingShare = false }
        do {
            // Precise iCloud diagnostics so we can see WHY sharing can't start.
            let status = try await app.cloud.container.accountStatus()
            guard status == .available else {
                switch status {
                case .noAccount:
                    shareError = "No iCloud account on this device. Open Settings ▸ [your name] ▸ iCloud and sign in, then try again."
                case .restricted:
                    shareError = "iCloud is restricted on this device (Screen Time / MDM). Sharing needs iCloud enabled."
                case .couldNotDetermine:
                    shareError = "Couldn't reach iCloud. Check your internet connection and try again."
                case .temporarilyUnavailable:
                    shareError = "iCloud is temporarily unavailable. Try again in a moment."
                @unknown default:
                    shareError = "iCloud isn't available on this device."
                }
                return
            }
            let share = try await app.cloud.createShare(title: spaceName.isEmpty ? "Our Space" : spaceName)
            cloudShare = share
            if let url = share.url {
                inviteLink = url.absoluteString
            } else {
                // Share saved but URL not yet populated — present the native sheet,
                // which can still send it (Messages / Copy Link / etc.).
                showCloudShare = true
            }
        } catch {
            shareError = "Couldn't create the invite link: \(error.localizedDescription)"
        }
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
                TextField("Our space", text: $spaceName)
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
                if inviteLink.isEmpty {
                    Text("Tap “Create space & invite link” below to generate a secure link. Share it in any app — when \(partnerName) taps it, Tweli opens and asks them to join.")
                        .font(.footnote).foregroundStyle(.secondary)

                    if let shareError {
                        Label(shareError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Color.twWarn)
                    }
                } else {
                    Text("Share this link so \(partnerName) can join your space.")
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

                    Button {
                        showLinkShare = true   // normal share sheet → WhatsApp / Messages / Copy
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share invite").fontWeight(.semibold)
                        }
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity).padding(14)
                        .foregroundStyle(.white).background(Color.twAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var continueBar: some View {
        VStack(spacing: 10) {
            if inviteLink.isEmpty {
                // Primary path: create the space AND its shareable invite link.
                PrimaryButton(title: preparingShare ? "Creating link…" : "Create space & invite link",
                              systemImage: preparingShare ? "hourglass" : "link") {
                    Task { await createInviteLink() }   // shows the copyable link inline
                }
                .disabled(preparingShare || spaceName.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Skip — set up the link later") { couple.createSpace(title: spaceName) }
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                // Link is ready — enter the shared space.
                PrimaryButton(title: "Continue", systemImage: "heart.fill") {
                    couple.createSpace(title: spaceName)
                }
            }
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 8)
        .background(.bar)
    }
}

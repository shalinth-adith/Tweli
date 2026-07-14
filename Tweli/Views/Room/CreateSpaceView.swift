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
    @State private var inviteLink = ""          // tweli://join?code=… once the code exists
    @State private var pairCode = ""            // 6-char code published to the public DB
    @State private var copied = false
    @State private var codeCopied = false
    @State private var preparingShare = false
    @State private var shareError: String?

    private var partnerName: String { app.partner?.displayName ?? "your partner" }

    /// "7GK4PB" → "7GK-4PB" for readability.
    private var displayCode: String {
        pairCode.count == 6 ? "\(pairCode.prefix(3))-\(pairCode.suffix(3))" : pairCode
    }

    /// What actually gets sent to the partner. The iCloud link is the tappable
    /// door (WhatsApp/iMessage only linkify https URLs — custom tweli:// schemes
    /// render as plain text there); the code is the typeable fallback.
    private var shareMessage: String {
        var lines = ["💞 Join me on Tweli!"]
        if !inviteLink.isEmpty { lines.append("\nTap to join: \(inviteLink)") }
        if !pairCode.isEmpty {
            lines.append("\nOr open Tweli ▸ Join space ▸ enter code: \(displayCode)")
        }
        return lines.joined(separator: "\n")
    }

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
    }

    /// Does the whole invite dance inline: create (or reuse) the space, then
    /// publish the 6-char pairing code. Two quick Firestore writes — no
    /// server-minted URL to poll for, and no dependency on the user's iCloud
    /// account or storage. The code IS the invite; the tweli:// link just
    /// carries it. Every failure surfaces as a visible message, never a
    /// silent spinner.
    private func createInviteLink() async {
        preparingShare = true
        shareError = nil
        defer { preparingShare = false }
        do {
            let title = spaceName.isEmpty ? "Our Space" : spaceName

            // 1. Create the space once; re-taps reuse it (role flips to
            //    .owner on the first success).
            if app.cloud.role != .owner {
                _ = try await app.cloud.createSpace(title: title)
            }

            // 2. Publish (or reuse an unexpired) pairing code.
            let code = try await app.cloud.publishPairCode(spaceTitle: title)
            pairCode = code
            inviteLink = "tweli://join?code=\(code)"
        } catch let e as FirebaseService.PairCodeError {
            shareError = e.localizedDescription
            print("[Firebase] createInviteLink failed: \(e)")
        } catch {
            shareError = "Couldn't create the invite link: \(error.localizedDescription)"
            print("[Firebase] createInviteLink failed: \(error)")
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
                    Text("Share this invite so \(partnerName) can join your space.")
                        .font(.footnote).foregroundStyle(.secondary)

                    if !pairCode.isEmpty { codeCard }

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

                    // Native SwiftUI share — a UIKit UIActivityViewController wrapped
                    // in a .sheet renders a black screen on modern iOS.
                    ShareLink(item: shareMessage) {
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

    /// The big, friendly pairing code — the easiest thing to read out or type.
    private var codeCard: some View {
        VStack(spacing: 6) {
            Text("INVITE CODE")
                .font(.caption2.weight(.bold))
                .kerning(1.2)
                .foregroundStyle(.tertiary)
            Text(displayCode)
                .font(.system(size: 34, weight: .heavy, design: .monospaced))
                .kerning(2)
                .foregroundStyle(Color.twAccent)
            Button {
                UIPasteboard.general.string = pairCode
                withAnimation { codeCopied = true }
                Task { try? await Task.sleep(nanoseconds: 1_500_000_000); withAnimation { codeCopied = false } }
            } label: {
                Label(codeCopied ? "Copied" : "Copy code", systemImage: codeCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .foregroundStyle(Color.twAccent)
                    .background(Color.twAccentSoft, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(UIColor.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
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

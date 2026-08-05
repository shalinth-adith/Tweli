//
//  CreateSpaceView.swift
//  Tweli
//
//  Design 19c/19d (Name your space) → 19e/19f (Invite code). Two steps in one
//  flow: name the shared space, create it on the backend + mint a pairing code,
//  then present the code to share. "Continue" hands off to the full-screen
//  waiting screen (JoiningView, 19g/h) via AppViewModel.
//

import SwiftUI
import UIKit

struct CreateSpaceView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @Environment(\.dismiss) private var dismiss

    enum Step { case name, invite }
    @State private var step: Step = .name

    @State private var spaceName = ""
    @State private var pairCode = ""
    @State private var creating = false
    @State private var error: String?
    @State private var copied = false

    /// Where "I have an invite code instead" should route. Set by the parent.
    var onSwitchToJoin: (() -> Void)?

    private var title: String {
        let t = spaceName.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "Our space" : t
    }
    private var youInitial: String { couple.currentUser.initials }

    /// Tappable universal link — opens Tweli straight to Join with the code
    /// filled (or the App Store if they don't have Tweli yet).
    private var inviteLink: String { "https://tweli-9a99e.web.app/join?code=\(pairCode)" }

    private var shareMessage: String {
        var lines = ["💞 Join me on Tweli!"]
        if !pairCode.isEmpty {
            lines.append("\nTap to join us: \(inviteLink)")
            lines.append("\nOr open Tweli ▸ Join a space ▸ enter code: \(displayCode)")
        }
        return lines.joined(separator: "\n")
    }
    /// "TWLI4821" → "TWLI-4821" (comp A5).
    private var displayCode: String { FirebaseService.formatPairCode(pairCode) }

    /// The code's own deadline — comp A5 "Expires in 48 hours", comp E3 once past.
    private var expiresAt: Date? { app.cloud.pairCodeExpiresAt }
    private var isExpired: Bool { expiresAt.map { $0 < Date() } ?? false }

    /// "Expires in 41 hours" / "Expires in 24 minutes".
    private var expiryLine: String {
        guard let expiresAt else { return "Opens your space exactly once" }
        let secs = expiresAt.timeIntervalSinceNow
        if secs <= 0 {
            let ago = -secs
            let h = Int(ago) / 3600
            return h >= 1 ? "Expired \(h) hour\(h == 1 ? "" : "s") ago" : "Expired just now"
        }
        let hours = Int(secs) / 3600
        if hours >= 1 { return "Expires in \(hours) hour\(hours == 1 ? "" : "s")" }
        let mins = max(1, Int(secs) / 60)
        return "Expires in \(mins) minute\(mins == 1 ? "" : "s")"
    }

    var body: some View {
        ZStack {
            Color.twBackground.ignoresSafeArea()
            switch step {
            case .name:   nameStep
            case .invite: inviteStep
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header (back + progress dots)

    private func header(active: Int) -> some View {
        HStack {
            Button {
                if step == .invite { withAnimation { step = .name } } else { dismiss() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.twInk)
                    .frame(width: 34, height: 34)
                    .background(Color.twInkTertiary.opacity(0.22), in: Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 6) {
                Capsule().fill(active == 0 ? Color.twAccent : Color.twInkTertiary.opacity(0.3))
                    .frame(width: active == 0 ? 22 : 6, height: 6)
                Capsule().fill(active == 1 ? Color.twAccent : Color.twInkTertiary.opacity(0.3))
                    .frame(width: active == 1 ? 22 : 6, height: 6)
            }
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Step 1 · Name (19c/19d)

    private var nameStep: some View {
        VStack(spacing: 0) {
            header(active: 0)
            ScrollView {
                VStack(spacing: 0) {
                    pairingHero.padding(.top, 20)

                    VStack(spacing: 8) {
                        Text("Name your space")
                            .font(.system(size: 28, weight: .heavy)).tracking(-0.6)
                            .foregroundStyle(Color.twInk)
                        Text("One shared world for the two of you.\nYou can change it anytime.")
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.twInkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    nameField.padding(.top, 26)
                    suggestionChips.padding(.top, 14)

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(Color.twAccentInk)
                            .padding(.top, 14)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }

            VStack(spacing: 10) {
                BrandCTA(title: creating ? "Creating…" : "Create our space", loading: creating) {
                    Task { await createSpace() }
                }
                .disabled(creating || spaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(spaceName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                Button("I have an invite code instead") {
                    if let onSwitchToJoin { onSwitchToJoin() } else { dismiss() }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.twInkSecondary)
                .frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var pairingHero: some View {
        HStack(spacing: 0) {
            ProfileAvatar(profile: couple.currentUser, isPartner: false, size: 58)
            Image(systemName: "ellipsis")
                .font(.title3).foregroundStyle(Color.twInkTertiary)
                .padding(.horizontal, 10)
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundStyle(Color.twInkTertiary)
                .frame(width: 58, height: 58)
                .overlay(Image(systemName: "plus").font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.twInkTertiary))
        }
    }

    private var nameField: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill").foregroundStyle(Color.twAccent)
            TextField("Our space", text: $spaceName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.twInk)
                .submitLabel(.done)
        }
        .padding(17)
        .background(Color.twElevated,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.twAccent.opacity(0.35), lineWidth: 1.5)
        }
    }

    /// Name suggestions — deliberately name-free so nothing is hardcoded.
    private var suggestionChips: some View {
        HStack(spacing: 8) {
            ForEach(["Us two", "Our little world", "Home"], id: \.self) { s in
                Button { spaceName = s } label: {
                    Text(s)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.twAccent2)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.twAccent2Soft, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Step 2 · Invite code (comp A5, and E3 once it expires)

    private var inviteStep: some View {
        VStack(spacing: 0) {
            header(active: 1)
            Spacer(minLength: 8)
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isExpired ? Color.twWarn.opacity(0.15) : Color.twSuccess.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: isExpired ? "clock.badge.exclamationmark" : "checkmark")
                        .font(.system(size: isExpired ? 27 : 26, weight: .heavy))
                        .foregroundStyle(isExpired ? Color.twWarn : Color.twSuccess)
                }

                Text(isExpired ? "This code expired" : "Invite your partner")
                    .font(.system(size: 28, weight: .heavy)).tracking(-0.6)
                    .foregroundStyle(Color.twInk)
                    .padding(.top, 18)

                Text(isExpired
                     ? "Codes last 48 hours so only the right person can use them. Nothing was lost."
                     : "Send this code any way you like. It opens \(title) exactly once.")
                    .font(.system(size: 14.5))
                    .lineSpacing(3)
                    .foregroundStyle(Color.twInkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                Text(isExpired ? "Old code" : "Your code")
                    .tweliEyebrow()
                    .tracking(1.2)
                    .padding(.top, 28)

                codeTiles.padding(.top, 10).opacity(isExpired ? 0.45 : 1)

                Text(expiryLine)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(isExpired ? Color.twWarnInk : Color.twInkTertiary)
                    .padding(.top, 12)

                if !isExpired { shareButtons.padding(.top, 20) }
            }
            .padding(.horizontal, 24)
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                if isExpired {
                    BrandCTA(title: creating ? "Minting a new code…" : "Generate a fresh code",
                             loading: creating, showsArrow: false) {
                        Task { await regenerate() }
                    }
                    .disabled(creating)
                } else {
                    BrandCTA(title: "Continue") { app.beginOwnerWaiting(title: title) }
                    Text("You don't have to wait — they can join anytime.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.twInkTertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    /// Eight monospaced tiles split 4 + 4, mirroring the entry screen.
    private var codeTiles: some View {
        HStack(spacing: 5) {
            let chars = Array(displayCode.filter { $0 != "-" })
            ForEach(Array(chars.enumerated()), id: \.offset) { idx, ch in
                if idx == 4 {
                    Capsule()
                        .fill(Color.twInkTertiary.opacity(0.35))
                        .frame(width: 10, height: 3)
                        .padding(.horizontal, 2)
                }
                Text(String(ch))
                    .font(.system(size: 21, weight: .bold, design: .monospaced))
                    .foregroundStyle(idx < 4 ? Color.twInk : Color.twAccentInk)
                    .frame(width: 34, height: 48)
                    .background(Color.twElevated,
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.twHairline, lineWidth: 1)
                    }
            }
        }
    }

    private var shareButtons: some View {
        HStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = displayCode
                withAnimation { copied = true }
                Task { try? await Task.sleep(nanoseconds: 1_500_000_000); withAnimation { copied = false } }
            } label: {
                actionTile(copied ? "Copied" : "Copy code",
                           icon: copied ? "checkmark" : "doc.on.doc",
                           tint: .twAccent2)
            }
            .buttonStyle(PressableButtonStyle())

            ShareLink(item: shareMessage) {
                actionTile("Share code", icon: "square.and.arrow.up", tint: .twAccent)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func actionTile(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            Text(text).font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity).frame(height: 48)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Backend

    /// Comp E3 — mint a brand-new code and drop the expired one.
    private func regenerate() async {
        creating = true
        error = nil
        defer { creating = false }
        do {
            pairCode = try await app.cloud.regeneratePairCode(spaceTitle: title)
        } catch let e as FirebaseService.PairCodeError {
            error = e.localizedDescription
        } catch {
            self.error = "Couldn't refresh your code: \(error.localizedDescription)"
        }
    }

    private func createSpace() async {
        creating = true
        error = nil
        defer { creating = false }
        do {
            if app.cloud.role != .owner {
                _ = try await app.cloud.createSpace(title: title)
            }
            pairCode = try await app.cloud.publishPairCode(spaceTitle: title)
            withAnimation(.easeInOut) { step = .invite }
        } catch let e as FirebaseService.PairCodeError {
            error = e.localizedDescription
        } catch {
            self.error = "Couldn't create your space: \(error.localizedDescription)"
        }
    }
}

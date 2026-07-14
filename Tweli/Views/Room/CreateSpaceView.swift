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

    private var shareMessage: String {
        var lines = ["💞 Join me on Tweli!"]
        if !pairCode.isEmpty {
            lines.append("\nOpen Tweli ▸ Join a space ▸ enter code: \(displayCode)")
            lines.append("\nOr tap: tweli://join?code=\(pairCode)")
        }
        return lines.joined(separator: "\n")
    }
    private var displayCode: String {
        pairCode.count == 6 ? "\(pairCode.prefix(3))-\(pairCode.suffix(3))" : pairCode
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .background(Color.primary.opacity(0.06), in: Circle())
            }
            Spacer()
            HStack(spacing: 6) {
                Capsule().fill(active == 0 ? Brand.pink : Color.primary.opacity(0.18))
                    .frame(width: active == 0 ? 22 : 6, height: 6)
                Capsule().fill(active == 1 ? Brand.pink : Color.primary.opacity(0.18))
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
                            .font(.system(size: 28, weight: .heavy)).kerning(-0.6)
                            .foregroundStyle(.primary)
                        Text("One shared world for the two of you.\nYou can change it anytime.")
                            .font(.system(size: 14.5))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    nameField.padding(.top, 26)
                    suggestionChips.padding(.top, 14)

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(Brand.pink)
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
                .foregroundStyle(.secondary)
                .frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var pairingHero: some View {
        HStack(spacing: 0) {
            AvatarBubble(initial: youInitial, isPartner: false, size: 58)
            Image(systemName: "ellipsis")
                .font(.title3).foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundStyle(.tertiary)
                .frame(width: 58, height: 58)
                .overlay(Image(systemName: "plus").font(.system(size: 20, weight: .semibold)).foregroundStyle(.tertiary))
        }
    }

    private var nameField: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill").foregroundStyle(Brand.pink)
            TextField("Our space", text: $spaceName)
                .font(.system(size: 18, weight: .semibold))
                .submitLabel(.done)
        }
        .padding(17)
        .background(Color(UIColor.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Brand.pink.opacity(0.35), lineWidth: 1.5)
        )
    }

    /// Name suggestions — deliberately name-free so nothing is hardcoded.
    private var suggestionChips: some View {
        HStack(spacing: 8) {
            ForEach(["Us two", "Our little world", "Home"], id: \.self) { s in
                Button { spaceName = s } label: {
                    Text(s)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Brand.indigo)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Brand.indigo.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Step 2 · Invite code (19e/19f)

    private var inviteStep: some View {
        VStack(spacing: 0) {
            header(active: 1)
            Spacer()
            VStack(spacing: 0) {
                Circle()
                    .fill(Brand.green.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "checkmark").font(.system(size: 26, weight: .heavy)).foregroundStyle(Brand.green))

                Text("Your space is ready")
                    .font(.system(size: 28, weight: .heavy)).kerning(-0.6)
                    .foregroundStyle(.primary)
                    .padding(.top, 18)
                Text("Share this code with your partner\nto join \(title).")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                codeTiles.padding(.top, 28)
                shareButtons.padding(.top, 20)
            }
            .padding(.horizontal, 24)
            Spacer()

            VStack(spacing: 10) {
                BrandCTA(title: "Continue") { app.beginOwnerWaiting(title: title) }
                Text("You don't have to wait — they can join anytime.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var codeTiles: some View {
        HStack(spacing: 7) {
            let chars = Array(pairCode)
            ForEach(Array(chars.enumerated()), id: \.offset) { idx, ch in
                if idx == 3 {
                    Capsule().fill(Color.primary.opacity(0.2)).frame(width: 12, height: 3)
                }
                Text(String(ch))
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(idx < 3 ? .primary : Color(Brand.pink))
                    .frame(width: 44, height: 56)
                    .background(Color(UIColor.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        }
    }

    private var shareButtons: some View {
        HStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = pairCode
                withAnimation { copied = true }
                Task { try? await Task.sleep(nanoseconds: 1_500_000_000); withAnimation { copied = false } }
            } label: {
                tile(copied ? "Copied" : "Copy code", icon: copied ? "checkmark" : "doc.on.doc", tint: Brand.indigo)
            }
            .buttonStyle(.plain)

            ShareLink(item: shareMessage) {
                tile("Share invite", icon: "square.and.arrow.up", tint: Brand.pink)
            }
            .buttonStyle(.plain)
        }
    }

    private func tile(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            Text(text).font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity).frame(height: 48)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Backend

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
